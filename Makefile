TARGET := cl-swayipc
  BUILD_DIR := build

  all: $(TARGET)

  $(TARGET):
  	sbcl --no-userinit --no-sysinit --non-interactive \
  		 --eval '(load (sb-ext:posix-getenv "ASDF"))' \
  		 --load ./cl-swayipc.asd \
  		 --eval '(asdf:make :cl-swayipc)' \
  		 --eval '(quit)'

  clean:
  	-rm -f $(BUILD_DIR)/$(TARGET)
  