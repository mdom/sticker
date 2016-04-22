package App::Sticker::Util;
use strict;
use warnings;
use Moo::Role;

use Mojo::URL;

sub to_url {
    my ( $self, @urls ) = @_;
    my @normalized_urls;
    for my $url (@urls) {
        if ( $url =~ /^\d+/ ) {
            my $last_search = $self->base->base_dir->child('last_search');
            if ( $last_search->exists ) {
                my @urls = $last_search->lines( { chomp => 1 } );
                my @nums = map { $_ - 1 } $self->_expand_nums($url);
                push @normalized_urls, @urls[@nums];
            }
        }
        else {
            $url = $self->normalize_url($url);
            push @normalized_urls, $url;
        }
    }
    return @normalized_urls;
}

sub _expand_nums {
    my ( $self, $num ) = @_;
    my @nums;
    for my $num ( split( ',', $num ) ) {
        if ( $num =~ /^(\d+)-(\d+)$/ ) {
            push @nums, $1 .. $2;
        }
        else {
            push @nums, $num;
        }
    }
    return @nums;
}

1;
