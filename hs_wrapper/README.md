# C Wrapper for Hyperscan

Due to the limit of the luajit callback mechanism, We need a C wrapper to handle hyperscan callback.

> Callbacks take up resources — you can only have a limited number of them at the same time (500 - 1000, depending on the architecture). The associated Lua functions are anchored to prevent garbage collection, too.
> 
> **Callbacks are slow!**

## Build Wrapper

You should build the hyperscan library first. here are some pre-build blow:

- [CentOS](https://github.com/OpenSecHub/hyperscan-packaging/releases)

- [Ubuntu(hirsute)](https://packages.ubuntu.com/hirsute/libhyperscan-dev)

- [Debian(bullseye)](https://packages.debian.org/bullseye/libhyperscan-dev)

Then, build this wrapper library(libwhs.so).

```bash
yum install -y gcc make libstdc++-static

make all

cp libwhs.so /usr/local/openresty/site/lualib/
```

