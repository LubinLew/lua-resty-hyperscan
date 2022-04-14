
all:
	make -C hs_wrapper

test:
	make runtest -C hs_wrapper
	t/go.sh

install:
	cp hs_wrapper/libwhs.so /usr/local/openresty/site/lualib/
	cp lib/resty/hyperscan.lua /usr/local/openresty/lualib/resty/hyperscan.lua

clean:
	make clean -C hs_wrapper
