"""A tiny module the nixbox demo opens in neovim."""


def greet(name: str) -> str:
    return f"hello, {name}, from nixbox"


if __name__ == "__main__":
    print(greet("world"))
