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

sub normalize_url {
    my $self       = shift;
    my $url_string = shift;
    my $url        = Mojo::URL->new($url_string);
    ## If the user enters a url without a protocoll or a path, Mojo::URL parses
    ## the hostname as path.
    if ( not defined $url->host and defined $url->path ) {
        $url = Mojo::URL->new()->host( $url->path->trailing_slash(0) );
    }
    $url->scheme('http') if !$url->scheme;
    $url->authority('')  if !$url->authority;
    $url->port(undef)    if $url->port && $url->port == 80;
    $url->path('/')      if $url->path eq '';
    return $url;
}

1;
