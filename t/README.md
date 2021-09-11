# Test



## Functional Test

TOOL: Test::Nginx

```bash
yum install -y cpanminus
cpanm Test::Nginx --force

bash -x t/go.sh
```

> Notes:
>
> [Automated Testing - Programming OpenResty](https://openresty.gitbooks.io/programming-openresty/content/testing/)
>
> [openresty/test-nginx: Data-driven test scaffold for Nginx C module and OpenResty Lua library development](https://github.com/openresty/test-nginx)

-------

## Performance Test

TOOL: wrk

```bash
wget https://github.com/wg/wrk/archive/refs/tags/4.1.0.tar.gz
tar xf 4.1.0.tar.gz
cd wrk-4.1.0
make -j4
cp wrk /usr/bin/

wrk -t20 -c4000 -d60s http://localhost/index.html
```

> Notes:
>
> [GitHub - wg/wrk: Modern HTTP benchmarking tool](https://github.com/wg/wrk)


