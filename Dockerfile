FROM ubuntu
# Various tools we need to build and test the sysroot
RUN apt update && apt install -y debootstrap xz-utils symlinks curl build-essential

# Run the appropriate debootstrap steps
COPY scripts/_debootstrap.sh /scripts/
RUN /scripts/_debootstrap.sh

# Clean the noisiest parts of the sysroot
RUN rm -rf /sysroot/var/cache
RUN rm -rf /sysroot/var/lib/dpkg
RUN rm -rf /sysroot/usr/share/man
RUN rm -rf /sysroot/usr/share/doc

# Fix relative symlinks
COPY scripts/_fix_symlinks.sh /scripts/
RUN /scripts/_fix_symlinks.sh

# Provide a /sysroot/.env that sets up the appropriate Rust and C flags
RUN echo "# Compiler flags" > /sysroot/.env
RUN echo export RUSTFLAGS=\"-C link-arg=-L/sysroot/lib/`uname -m`-unknown-linux-gnu -C link-arg=-L/sysroot/usr/lib/`uname -m`-unknown-linux-gnu -C link-arg=--sysroot=/sysroot $RUSTFLAGS\" >> /sysroot/.env
RUN echo export CFLAGS=\"-L/sysroot/lib/`uname -m`-unknown-linux-gnu -L/sysroot/usr/lib/`uname -m`-unknown-linux-gnu --sysroot=/sysroot $CFLAGS\" >> /sysroot/.env

# Test the sysroot by building a Rust program that uses various bits of libc/libm/libdl and trying
# to run it in a chroot /sysroot.
RUN curl https://sh.rustup.rs -sSf > /tmp/rustup-init.sh && sh /tmp/rustup-init.sh -y
COPY smoketest/ /tmp/smoketest/
WORKDIR /tmp/smoketest
RUN . /sysroot/.env && PATH=/root/.cargo/bin:$PATH cargo -vv build
RUN cp /tmp/smoketest/target/debug/smoketest /sysroot
RUN chroot "/sysroot" /smoketest
RUN rm /sysroot/smoketest
WORKDIR /

# Build and compress the sysroot, excluding the contents of /dev and /proc. Use
# the recommended flags from https://reproducible-builds.org/docs/archives/ to make
# the sysroot reproducible.
RUN tar \
    --exclude='/sysroot/dev/*' \
    --exclude='/sysroot/proc/*' \
    --sort=name \
    --mtime="@0" \
    --owner=0 --group=0 --numeric-owner \
    --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
    -cv sysroot/ > /tmp/sysroot.tar
# RUN xz -0 -z /tmp/sysroot.tar
RUN xz -9 -e -z /tmp/sysroot.tar
RUN mv /tmp/sysroot.tar.xz /tmp/sysroot-`uname -m`.tar.xz
RUN ls -l /tmp/sysroot-`uname -m`.tar.xz
