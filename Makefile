
all:
	cd hs_wrapper && make

test:
	cd hs_wrapper && make runtest
	t/go.sh

install:
	cp hs_wrapper/libwhs.so /usr/local/openresty/site/lualib/
	cp lib/resty/hyperscan.lua /usr/local/openresty/lualib/resty/hyperscan.lua