
COMMIT=$(shell git rev-parse HEAD)
VERSION=$(shell cat VERSION)
DATE=$(shell date +'%FT%TZ%z')

ifndef CC
CC=gcc
endif
ifndef AR
AR=ar
endif

ifeq ($(shell uname -s),Darwin)
CONFIG_DARWIN=y
else ifeq ($(OS),Windows_NT)
CONFIG_WINDOWS=y
else
CONFIG_LINUX=y
endif

ifdef CONFIG_DARWIN
LOADABLE_EXTENSION=dylib
endif

ifdef CONFIG_LINUX
LOADABLE_EXTENSION=so
endif

ifdef CONFIG_WINDOWS
LOADABLE_EXTENSION=dll
endif


ifdef python
PYTHON=$(python)
else
PYTHON=python3
endif

ifndef OMIT_SIMD
	ifeq ($(shell uname -sm),Darwin x86_64)
	CFLAGS += -mavx -DSQLITE_VEC_ENABLE_AVX
	endif
	ifeq ($(shell uname -sm),Darwin arm64)
	CFLAGS += -mcpu=apple-m1 -DSQLITE_VEC_ENABLE_NEON
	endif
endif

ifdef USE_BREW_SQLITE
	SQLITE_INCLUDE_PATH=-I/opt/homebrew/opt/sqlite/include
	SQLITE_LIB_PATH=-L/opt/homebrew/opt/sqlite/lib
	CFLAGS += $(SQLITE_INCLUDE_PATH) $(SQLITE_LIB_PATH)
endif

ifdef IS_MACOS_ARM
RENAME_WHEELS_ARGS=--is-macos-arm
else
RENAME_WHEELS_ARGS=
endif

prefix=dist
$(prefix):
	mkdir -p $(prefix)

TARGET_LOADABLE=$(prefix)/sample.$(LOADABLE_EXTENSION)
TARGET_STATIC=$(prefix)/libsqlite_sample.a
TARGET_CLI=$(prefix)/sqlite3

loadable: $(TARGET_LOADABLE)
static: $(TARGET_STATIC)
cli: $(TARGET_CLI)

all: loadable static cli

OBJS_DIR=$(prefix)/.objs
LIBS_DIR=$(prefix)/.libs
BUILD_DIR=$(prefix)/.build

$(OBJS_DIR): $(prefix)
	mkdir -p $@

$(LIBS_DIR): $(prefix)
	mkdir -p $@

$(BUILD_DIR): $(prefix)
	mkdir -p $@


$(TARGET_LOADABLE): sqlite-sample.c $(prefix)
	$(CC) \
		-fPIC -shared \
		-Wall -Wextra \
		-Ivendor/ \
		-O3 \
		$(CFLAGS) \
		$< -o $@

$(TARGET_STATIC): sqlite-sample.c $(prefix) $(OBJS_DIR)
	$(CC) -Ivendor/ -Ivendor/sample $(CFLAGS) -DSQLITE_CORE -DSQLITE_VEC_STATIC \
	-O3 -c  $< -o $(OBJS_DIR)/sample.o
	$(AR) rcs $@ $(OBJS_DIR)/sample.o

$(OBJS_DIR)/sqlite3.o: vendor/sqlite3.c $(OBJS_DIR)
	$(CC) -c -g3 -O3 -DSQLITE_EXTRA_INIT=core_init -DSQLITE_CORE -DSQLITE_ENABLE_STMT_SCANSTATUS -DSQLITE_ENABLE_BYTECODE_VTAB -DSQLITE_ENABLE_EXPLAIN_COMMENTS -I./vendor $< -o $@

$(LIBS_DIR)/sqlite3.a: $(OBJS_DIR)/sqlite3.o $(LIBS_DIR)
	$(AR) rcs $@ $<

$(BUILD_DIR)/shell-new.c: vendor/shell.c $(BUILD_DIR)
	sed 's/\/\*extra-version-info\*\//EXTRA_TODO/g' $< > $@

$(OBJS_DIR)/shell.o: $(BUILD_DIR)/shell-new.c $(OBJS_DIR)
	$(CC) -c -g3 -O3 \
		-I./vendor \
		-DSQLITE_ENABLE_STMT_SCANSTATUS -DSQLITE_ENABLE_BYTECODE_VTAB -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
		-DEXTRA_TODO="\"CUSTOMBUILD:sqlite-sample\n\"" \
		$< -o $@

$(LIBS_DIR)/shell.a: $(OBJS_DIR)/shell.o $(LIBS_DIR)
	$(AR) rcs $@ $<

$(OBJS_DIR)/sqlite-sample.o: sqlite-sample.c $(OBJS_DIR)
	$(CC) -c -g3 -Ivendor/ -I./ $(CFLAGS) $< -o $@

$(LIBS_DIR)/sqlite-sample.a: $(OBJS_DIR)/sqlite-sample.o $(LIBS_DIR)
	$(AR) rcs $@ $<

$(TARGET_CLI): $(LIBS_DIR)/sqlite-sample.a $(LIBS_DIR)/shell.a $(LIBS_DIR)/sqlite3.a examples/sqlite3-cli/core_init.c $(prefix)
	$(CC) -g3  \
	-Ivendor/ -I./ \
	-DSQLITE_CORE \
	-DSQLITE_VEC_STATIC \
	-DSQLITE_THREADSAFE=0 -DSQLITE_ENABLE_FTS4 \
	-DSQLITE_ENABLE_STMT_SCANSTATUS -DSQLITE_ENABLE_BYTECODE_VTAB -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
	-DSQLITE_EXTRA_INIT=core_init \
	$(CFLAGS) \
	-ldl -lm \
	examples/sqlite3-cli/core_init.c $(LIBS_DIR)/shell.a $(LIBS_DIR)/sqlite3.a $(LIBS_DIR)/sqlite-sample.a -o $@

clean:
	rm -rf dist


FORMAT_FILES=sqlite-sample.c
format: $(FORMAT_FILES)
	clang-format -i $(FORMAT_FILES)

lint: SHELL:=/bin/bash
lint:
	diff -u <(cat $(FORMAT_FILES)) <(clang-format $(FORMAT_FILES))
