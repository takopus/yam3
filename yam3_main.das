require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

let
    GEM_COLORS = 7
    FILE_NAMES = [[string[7]
        "blue";     // 0
        "green";    // 1
        "orange";   // 2
        "purple";   // 3
        "red";      // 4
        "yellow";   // 5
        "skull"]]   // 6
    FIELD_SIZE = int2(8, 8)
    CELL_SIZE = float2(64.0, 64.0)
    FIELD_OFFSET = float2(50.0, 50.0)
    IMG_SIZE = float2(54.0, 54.0)

    GEM_STATE_NULL = "null"
    GEM_STATE_STATIC = "static"
    GEM_STATE_OVER = "over"
    GEM_STATE_SELECTED = "selected"
    GEM_STATE_SWAPPING = "swapping"
    GEM_STATE_DYING = "dying"
    GEM_STATE_FALLING = "falling"

    OVER_SCALE = 1.3
    SELECTED_SCALE = 1.3
    UNDER_SCALE = 0.7
    DIE_SCALE = 0.1

    OVER_STEPS = 5.0
    OUT_STEPS = 20.0
    SELECTED_STEPS = 60.0
    SWAP_STEPS = 60.0
    DIE_STEPS = 60.0

    STATE_INTERACTIVE = "interactive"
    STATE_SWAPPING = "swapping"
    STATE_DYING = "dying"
    STATE_FALLING = "falling"

struct Gem
    id: string
    pos: float2 = float2(-1.0, -1.0)
    color: int
    state: string = GEM_STATE_NULL
    prev_state: string

    coords: float2
    scale: float = 1.0
    size: float2

    // common to over, blink, swap and die
    step: float

    // static and over:
    over_scale: float

    // swapping
    swap_is_top: bool
    swap_from: float2
    swap_to: float2

    // falling:
    fall_delay: int
    fall_speed: float
    fall_coords: float2
    fall_target: float

var
    RAND_SEED: int4
    field: array<array<int>>
    field_gems: table<string; Gem>
    field_state: string

    selected_gem = Gem()
    over_gem = Gem()

    render_bottom: array<Gem>
    render_middle: array<Gem>
    render_top: array<Gem>

    gem_images: array<ImageHandle>
    movesCount: int

    mouse_button = 0.0
    mouse_button_down = 0.0
    mouse_button_up = 0.0
    mouse_pos: float2

    log_msgs: array<string>
    dbg_stat1: string
    dbg_stat2: float2

// start value, end value, steps, current step
def ease_in_out_quad(var b, e, steps, s: float): float
    var x = s / steps
    x = x < 0.5 ? 2.0 * x * x : 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0
    return b + (e - b) * x


def ease_out_quad(var b, e, steps, s: float): float
    var x = s / steps
    x = 1.0 - (1.0 - x) * (1.0 - x)
    return b + (e - b) * x


def ease_in_quad(var b, e, steps, s: float): float
    var x = s / steps
    x = x * x
    return b + (e - b) * x

def log_msg(msg)
    emplace(log_msgs, "{length(log_msgs)}: {msg}", 0)

def init_images()
    var img: ImageHandle
    for i in range(0, GEM_COLORS)
        img <- create_managed_image("img/{FILE_NAMES[i]}.png")
        premultiply_alpha(img)
        make_image_color_transparent(img, get_pixel(img, 0, 0))
        set_image_smooth(img, true)
        push(gem_images, img)


def gen_field() : array<array<int>>
    var f: array<array<int>>
    var line: array<int>
    var c:int
    var hitV, hitH: bool
    for cy in range(0, FIELD_SIZE.y)
        clear(line)
        for cx in range(0, FIELD_SIZE.x)
            hitV = true
            while hitV || hitH
                hitV = false
                hitH = false
                c = random_int(RAND_SEED) % GEM_COLORS
                if cx > 1 && line[cx-1]==c && line[cx-2]==c
                    hitH = true
                if cy > 1 && f[cy-1][cx]==c && f[cy-2][cx]==c
                    hitV = true
            push(line, c)
        push_clone(f, line)
    return <- f


def swap_cells(f: array<array<int>>; cx, cy, dx, dy : int)
    var f_clone := f
    var swap_tmp1 = f_clone[cy][cx]
    var swap_tmp2 = f_clone[cy+dy][cx+dx]
    f_clone[cy][cx] = swap_tmp2
    f_clone[cy+dy][cx+dx] = swap_tmp1
    return <- f_clone


def check_hit(var f: array<array<int>>; var cx, cy: int) : int
    var c = f[cy][cx]
    var hits = 0
    var streak = 0
    var from_c = max(0, cx-2)
    var to_c = min(cx+3, FIELD_SIZE.x)
    for tx in range(from_c, to_c)
        if (f[cy][tx] == c)
            streak++
        elif (streak<3)
            streak = 0

    hits += streak >= 3 ? 1 : 0

    from_c = max(0, cy-2)
    to_c = min(cy+3, FIELD_SIZE.y)
    streak = 0
    for ty in range(from_c, to_c)
        if (f[ty][cx] == c)
            streak++
        elif (streak<3)
            streak = 0

    hits += streak >= 3 ? 1 : 0
    return hits


def get_moves_count(var f: array<array<int>>) : int
    var moves = 0
    var moved_f: array<array<int>>
    for cy in range(0, FIELD_SIZE.y)
        for cx in range(0, FIELD_SIZE.x)
            if (cx != FIELD_SIZE.x - 1)
                moved_f <- swap_cells(f, cx, cy, 1, 0)
                moves += check_hit(moved_f, cx, cy)
                moves += check_hit(moved_f, cx + 1, cy)
            if (cy != FIELD_SIZE.y - 1)
                moved_f <- swap_cells(f, cx, cy, 0, 1)
                moves += check_hit(moved_f, cx, cy)
                moves += check_hit(moved_f, cx, cy + 1)
    return moves


def init_field()
    var moves = 0
    var field_colors: array<array<int>>
    var safety = 999
    while moves < 1 && safety > 0
        field_colors <- gen_field()
        moves = get_moves_count(field_colors)
        safety--

    if safety == 0
        log_msg("ERROR: Can't gen board with available moves in 999 tries!")
    else
        log_msg("Board with {moves} moves available generated in {(999-safety)} cycles.")

    field <- field_colors

    for cy in range(0, FIELD_SIZE.y)
        for cx in range(0, FIELD_SIZE.x)
            var gem = Gem()
            gem.id = "{cx}-{cy}"
            gem.state = GEM_STATE_STATIC
            gem.pos.x = float(cx)
            gem.pos.y = float(cy)
            gem.size := IMG_SIZE
            gem.color = field[cy][cx]
            gem.coords.x = FIELD_OFFSET.x + float(cx) * CELL_SIZE.x + (CELL_SIZE.x - IMG_SIZE.x) / 2.0
            gem.coords.y = FIELD_OFFSET.y + float(cy) * CELL_SIZE.y + (CELL_SIZE.y - IMG_SIZE.y) / 2.0
            field_gems["{cx}-{cy}"] = gem


def update_coords(gem)
    var size = float2(gem.scale * IMG_SIZE.x, gem.scale * IMG_SIZE.y)
    var x = FIELD_OFFSET.x + gem.pos.x * CELL_SIZE.x + (CELL_SIZE.x - size.x) / 2.0
    var y = FIELD_OFFSET.y + gem.pos.y * CELL_SIZE.y + (CELL_SIZE.y - size.y) / 2.0
    field_gems[gem.id].coords = float2(x, y)


def update_field()
    clear(render_bottom)
    clear(render_middle)
    clear(render_top)   
    for key, gem in keys(field_gems), values(field_gems)

        if gem.state == GEM_STATE_NULL
            continue

        if gem.state == GEM_STATE_STATIC
            // fading over and selected:
            if gem.step > 0.0
                gem.step--
                var scale_from = gem.prev_state == GEM_STATE_OVER ? OVER_SCALE : SELECTED_SCALE
                gem.scale = ease_in_out_quad(1.0, scale_from, OUT_STEPS, gem.step)
                update_coords(gem)
            push(render_bottom, gem)
            continue

        if gem.state == GEM_STATE_OVER
            if gem.step < OVER_STEPS
                gem.step++
            gem.scale = ease_in_out_quad(1.0, OVER_SCALE, OVER_STEPS, gem.step)
            update_coords(gem)
            push(render_top, gem)
            continue

        if gem.state == GEM_STATE_SELECTED         
            gem.step++
            gem.scale = (gem.step < SELECTED_STEPS / 2.0
                ? ease_in_out_quad(1.0, SELECTED_SCALE, SELECTED_STEPS / 2.0, gem.step)
                : ease_in_out_quad(SELECTED_SCALE, 1.0, SELECTED_STEPS / 2.0, gem.step - SELECTED_STEPS / 2.0))
            dbg_stat2 = float2(gem.scale * 100.0, gem.step / 60.0 * 100.0)
            if gem.step >= SELECTED_STEPS
                gem.step = 0.0
            update_coords(gem)
            push(render_top, gem)
            continue

    // GEM_STATE_SWAPPING = "swapping"
    // GEM_STATE_DYING = "dying"
    // GEM_STATE_FALLING = "falling"
        if gem.state == GEM_STATE_SWAPPING
            gem.step++
            gem.pos.x = ease_in_out_quad(gem.swap_from.x, gem.swap_to.x, SWAP_STEPS, gem.step)
            gem.pos.y = ease_in_out_quad(gem.swap_from.y, gem.swap_to.y, SWAP_STEPS, gem.step)
            if gem.swap_is_top
                push(render_top, gem)
                gem.scale = (gem.step < SWAP_STEPS / 2.0
                    ? ease_in_quad(SELECTED_SCALE, OVER_SCALE, SWAP_STEPS / 2.0, gem.step - SWAP_STEPS / 2.0)
                    : OVER_SCALE)

            else
                push(render_middle, gem)
                gem.scale = (gem.step < SWAP_STEPS / 2.0
                    ? ease_out_quad(OVER_SCALE, UNDER_SCALE, SWAP_STEPS / 2.0, gem.step)
                    : ease_in_quad(UNDER_SCALE, 1.0, SWAP_STEPS / 2.0, gem.step - SWAP_STEPS / 2.0))
            
            update_coords(gem)
            continue


def draw_gem(gem: Gem; set_idx, gem_idx: int)
    var size = float2(gem.scale * IMG_SIZE.x, gem.scale * IMG_SIZE.y)
    draw_image(gem_images[gem.color], gem.coords.x, gem.coords.y, make_color(1.0), size)
    //text_out(gem.coords.x + 20.0, gem.coords.y + 20.0, "{gem.id}", 0xFFFFFFFF)
    //text_out(gem.coords.x + 20.0, gem.coords.y + 40.0, "{set_idx}:{gem_idx}", 0xFFFFFFFF)


def draw_field()
    enable_alpha_blend()
    var set_idx = 0
    for render_set in [{auto render_bottom; render_middle; render_top}]
        var gem_idx = 0
        for gem in render_set
            draw_gem(gem, set_idx, gem_idx)
            gem_idx++
        set_idx++

    disable_alpha_blend()

def draw_log()
    var y: int
    var lines = min(length(log_msgs), 25)
    for idx in range(0, lines)
        y = 50 + 20 * idx
        text_out(600, y, log_msgs[idx], 0xF0F0F0)

def to_string_gem(gem: Gem)
    if gem.state == GEM_STATE_NULL || gem.state == ""
        return "null"
    var px = int(gem.pos.x)
    var py = int(gem.pos.y)
    var step = int(gem.step)
    return "state: {gem.state}, pos: {px}:{py}, color: {FILE_NAMES[gem.color]}, step: {step}"

def draw_stats()
    var moves = get_moves_count(field)
    var over_gem_str = to_string_gem(field_gems[over_gem.id])
    var selected_gem_str = to_string_gem(field_gems[selected_gem.id])
    text_out(50, 582, "Moves count: {moves}", 0xF0F0F0)
    text_out(50, 602, "Over gem: {over_gem_str}", 0xF0F0F0)
    text_out(50, 622, "Selected gem: {selected_gem_str}", 0xF0F0F0)
    text_out(50, 642, "dbg_stat1: {dbg_stat1}", 0xF0F0F0)

def log_gem(gem: Gem; var pref: string = "")
    pref = pref != "" ? "{pref} -" : pref
    var gem_str = to_string_gem(gem)
    log_msg("{pref}{gem_str}")


// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("Yet Another Match-3")
    randomize_seed(RAND_SEED)
    init_images()
    init_field()
    field_state = STATE_INTERACTIVE
    return

def set_over_gem(var gem: Gem)
    // if previous is not null, fade it:
    if (over_gem.state != GEM_STATE_NULL)
        over_gem.state = GEM_STATE_STATIC
        over_gem.prev_state = GEM_STATE_OVER
        over_gem.step = OUT_STEPS
        field_gems[over_gem.id] = over_gem

    over_gem = gem
    // if it's not selected:
    if over_gem.state != GEM_STATE_NULL
        over_gem.state = GEM_STATE_OVER
        over_gem.step = 0.0
        if over_gem.id == ""
            dbg_stat1 = "new over, {over_gem.pos.x}"
        field_gems[over_gem.id] = over_gem
        log_gem(over_gem)

def set_selected_gem(gem)
    // there was something selected before
    if (selected_gem.state != GEM_STATE_NULL)
        selected_gem.state = GEM_STATE_STATIC
        selected_gem.prev_state = GEM_STATE_SELECTED
        var cur_sel_step = field_gems[selected_gem.id].step
        selected_gem.step = OUT_STEPS / (SELECTED_STEPS / 2.0) * (cur_sel_step > SELECTED_STEPS / 2.0 
            ? SELECTED_STEPS - cur_sel_step
            : cur_sel_step)
        if selected_gem.id == ""
            dbg_stat1 = "prev selected"
        field_gems[selected_gem.id] = selected_gem
    // set new selected:
    over_gem = Gem()
    selected_gem = gem
    selected_gem.state = GEM_STATE_SELECTED
    selected_gem.step = SELECTED_STEPS / 2.0
    if selected_gem.id == ""
        dbg_stat1 = "new selected"
    field_gems[selected_gem.id] = selected_gem

def process_mouse()
    mouse_pos = get_mouse_position()
    var mouse_cell = int2(floor((mouse_pos.x - FIELD_OFFSET.x) / CELL_SIZE.x), floor((mouse_pos.y - FIELD_OFFSET.y) / CELL_SIZE.y))

    var mouse_gem: Gem = (mouse_cell.x < 0 || mouse_cell.x >= FIELD_SIZE.x || mouse_cell.y < 0 || mouse_cell.y >= FIELD_SIZE.y
        ? Gem()
        : field_gems["{mouse_cell.x}-{mouse_cell.y}"])

    // over gem changed
    dbg_stat1 = "{over_gem.id} - {mouse_gem.id} - {selected_gem.id}"
    if over_gem.id != mouse_gem.id && !(selected_gem.state != GEM_STATE_NULL && selected_gem.id == mouse_gem.id)
        set_over_gem(mouse_gem)

    // clicked on gem, which wasn't selected before
    if get_mouse_button_up(MB_LEFT) && mouse_gem.pos.x != -1.0 && selected_gem.pos != mouse_gem.pos
        set_selected_gem(mouse_gem)


// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if field_state == STATE_INTERACTIVE
        process_mouse()

    update_field()
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    draw_field()
    draw_stats()
    draw_log()
    return