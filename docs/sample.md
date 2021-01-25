# サンプルコード

## fibonacci.root

入力された数のフィボナッチ数を 1 から順番に出力するプログラムです。

```
let fibonacci = fn(x) {
    if (x == 0) {
        return 0;
    } else {
        if (x == 1) {
            return 1;
        } else {
            return fibonacci(x - 1) + fibonacci(x - 2);
        }
    }
};

print("How many?(one of more)");
let num = readNum();

let i = 1;
loop {
    print(fibonacci(i));
    let i = i + 1;
    if (i > num) {
        return;
    }
}
```

## leap_year.root

入力された年がうるう年かどうかを判定すプログラムです。

```
let mod = fn(x, y) {
    if (x / y < 1) {
        if (x / y == 0) {
            return x/y;
        }
        return x;
    }
    let result = x / y;
    mod(result, y);
};

print("年を入力してください。");
let year = readNum();

if (mod(year, 400) == 0) {
    print("うるう年です。");
} else {
    if(mod(year, 100) == 0) {
        print("うるう年ではありません。");
    } else {
        if(mod(year, 4) == 0) {
            print("うるう年です。");
        } else {
            print("うるう年ではありません。");
        }
    }
}
```
