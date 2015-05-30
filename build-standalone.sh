PERL5LIB=./lib:$PERL5LIB

fatten --strip --overwrite --include-dir=lib --include=File::Spec --exclude-dist=Class-XSAccessor --exclude=IO::Socket::IP -o sticker-standalone script/sticker
