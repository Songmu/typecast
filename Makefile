# $Id$

BUILD_LANGUAGE ?= en_US
BUILD_PACKAGE ?= MTOS

-include mt/build/mt-dists/default.mk
-include mt/build/mt-dists/$(BUILD_PACKAGE).mk

all: install

install: depends_modules mtos

depends_modules:
	perl -Ilib -MCPAN -e 'install Bundle::TypeCast'

mtos: mt/lib/MT.pm

# mt/lib/MT.pm: %: %.pre mt/build/mt-dists/$(BUILD_PACKAGE).mk mt/build/mt-dists/default.mk
# 	sed -e 's!__BUILD_LANGUAGE__!$(BUILD_LANGUAGE)!g' \
# 	    -e 's!__PRODUCT_CODE__!$(PRODUCT_CODE)!g' \
# 	    -e 's!__PRODUCT_NAME__!$(PRODUCT_NAME)!g' \
# 	    -e 's!__PRODUCT_VERSION__!$(PRODUCT_VERSION)!g' \
# 	    -e 's!__PRODUCT_VERSION_ID__!$(BUILD_VERSION_ID)!g' \
# 	    -e 's!__SCHEMA_VERSION__!$(SCHEMA_VERSION)!g' \
# 	    -e 's!__API_VERSION__!$(API_VERSION)!g' \
# 	    -e 's!__NEWSBOX_URL__!$(NEWSBOX_URL)!g' \
# 	    -e 's!__LEARNINGNEWS_URL__!$(LEARNINGNEWS_URL)!g' \
# 	    -e 's!__SUPPORT_URL__!$(SUPPORT_URL)!g' \
# 	    -e 's!__PORTAL_URL__!$(PORTAL_URL)!g' \
# 	    -e 's!__NEWS_URL__!$(NEWS_URL)!g' \
# 	    -e 's!__DEFAULT_TIMEZONE__!$(DEFAULT_TIMEZONE)!g' \
# 	    -e 's!__MAIL_ENCODING__!$(MAIL_ENCODING)!g' \
# 	    -e 's!__EXPORT_ENCODING__!$(EXPORT_ENCODING)!g' \
# 	    -e 's!__LOG_EXPORT_ENCODING__!$(LOG_EXPORT_ENCODING)!g' \
# 	    -e 's!__CATEGORY_NAME_NODASH__!$(CATEGORY_NAME_NODASH)!g' \
# 	    -e 's!__PUBLISH_CHARSET__!$(PUBLISH_CHARSET)!g' \
# 	    $< > $@

test:
	@prove -l -Imt/lib -Imt/extlib t

clean:
	-rm -rf mt/lib/MT.pm
