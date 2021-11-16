require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

var
    RAND_SEED: int4
    image <- create_managed_image("yellow.png")
    test_field: array<array<int>>
    field: array<array<int>>
    matched: array<int2>
    GEM_COLORS = 7


def set_test_field()
    var test_field_str = ""

    test_field_str += "9 9 0 9 9 9 9 9\n"
    test_field_str += "9 9 0 9 9 9 9 9\n"
    test_field_str += "0 0 0 0 9 9 9 9\n"
    test_field_str += "9 9 9 9 9 9 9 9\n"
    test_field_str += "9 9 9 9 9 9 9 9\n"
    test_field_str += "9 9 9 9 9 0 0 0\n"
    test_field_str += "9 9 9 9 9 0 9 9\n"
    test_field_str += "9 9 9 9 9 0 9 9\n"

    if test_field_str == ""
        return

    var line: array<int>
    var lines <- split(test_field_str, "\n")
    for cy in range(0, length(lines) - 1)
        clear(line)
        var chars: array<string> <- split(lines[cy], " ")
        for char in chars
            push(line, char == "9" ? -1 : int(char))
        push_clone(test_field, line)

def testets(arr1, arr2:array<int2>)
    print("test arr1 len: {length(arr1)} \n")
    var res := arr1
    print("test res len: {length(res)} \n")
    return <- res

def add_if_new(var arr1, arr2:array<int2>)
    print(" job arr1 length: {length(arr1)}, arr2 length: {length(arr2)}  \n")
    var res: array<int2>
    clone(res, arr1)
    print(" job ress length: {length(res)}  \n")
    var got = 0
    for val in arr2
        if find_index(arr1, val) == -1
            push(res, val)
            got++
    print("   c: arr1 length: {length(arr1)}, arr2 length: {length(arr2)}, res length: {length(res)}, got: {got}  \n")
    return <- res


def gen_field() : array<array<int>>
    var f: array<array<int>>
    var line: array<int>
    var c:int
    var hitV, hitH: bool
    var is_testing = length(test_field) > 0
    for cy in range(0, 8)
        clear(line)
        for cx in range(0, 8)
            hitV = true
            while hitV || hitH
                hitV = false
                hitH = false
                if is_testing
                    c = test_field[cy][cx] == -1 ? (random_int(RAND_SEED) % (GEM_COLORS - 1) + 1) : test_field[cy][cx]
                else
                    c = random_int(RAND_SEED) % GEM_COLORS
                if !is_testing
                    if cx > 1 && line[cx-1]==c && line[cx-2]==c
                        hitH = true
                    if cy > 1 && f[cy-1][cx]==c && f[cy-2][cx]==c
                        hitV = true
            push(line, c)
        push_clone(f, line)
    return <- f


def get_matched(f: array<array<int>>; do_trace: bool = false) : array<int2>
    var res: array<int2>
    var color: int
    var streak: array<int2>

    for cx in range(0, 8)
        clear(streak)
        color = f[0][cx]
        push(streak, int2(cx,0))
        for cy in range(1, 8)
            if f[cy][cx] == color
                push(streak, int2(cx, cy))
            else
                if length(streak) >= 3
                    res <- add_if_new(res, streak)
                    print("1: res length: {length(res)} \n")
                    testets(res, streak)
                color = f[cy][cx]
                clear(streak)
                push(streak, int2(cx, cy))
        if length(streak) >= 3
            res <- add_if_new(res, streak)
            print("2: res length: {length(res)} \n")

    for cy in range(0, 8)
        clear(streak)
        color = f[cy][0]
        push(streak, int2(0, cy))
        for cx in range(1, 8)
            if f[cy][cx] == color
                push(streak, int2(cx, cy))
            else
                if length(streak) >= 3
                    res <- add_if_new(res, streak)
                    print("3: res length: {length(res)} \n")
                color = f[cy][cx]
                clear(streak)
                push(streak, int2(cx, cy))
        if length(streak) >= 3
            res <- add_if_new(res, streak)
            print("4: res length: {length(res)} \n")

    return <- res


def print_field()
    for cy in range(0, 8)
        for cx in range(0, 8)
            var val = int2(cx,cy)
            var color = find_index(matched, val) == -1 ? 0x808080 : 0xFFFFFF
            text_out(50 + cx * 20, 50 + cy * 20, string(field[cy][cx]), color)




// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    // set_window_title("playground")
    // randomize_seed(RAND_SEED)
    // set_test_field()
    // field <- gen_field()
    // matched <- get_matched(field)
    // for m in matched
    //     print("{m}\n")

    var a1: array<int2>
    push(a1, int2(0,0))
    push(a1, int2(1,0))
    push(a1, int2(2,0))
    push(a1, int2(3,0))
    var atmp: array<int2>
    var a2: array<int2>
    a2 <- testets(a1, atmp)
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    //print_field()
    return
