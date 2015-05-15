package App::Sticker::DB;

use strict;
use warnings;
use feature "state";
use Moo;
use Mojo::Collection 'c';
use Mojo::ByteStream 'b';

has base_dir => ( is => 'ro', required => 1);

sub create {
    my ($self) = @_;
    $self->base_dir->mkpath();
    return;
}

sub _parse_file {
    my $file = shift;
    my %attrs;
    if ( $file->exists ) {
        # TODO Line folding
        my $content = $file->slurp_utf8;
        %attrs = ( $content =~ /^(\S+?):\s*(.*)/gm );
    }
    return %attrs;
}

sub get_key_hash {
    my ($self,$string) = @_;
    return b($string)->sha1_sum;
}

sub get_file {
    my ( $self, $key ) = @_;
    my $hash = $self->get_key_hash($key);
    return $self->base_dir->child($hash);
}

sub get {
    my ( $self, $key, @props ) = @_;
    my $hash = $self->get_key_hash($key);
    my %attrs = $self->_parse_file( $self->get_file($hash) );
    return @attrs{@props};
}

sub delete {
    my ( $self, $key ) = @_;
    return $self->get_file($key)->remove();
}

sub set {
    my ( $self, $key, %new_attrs ) = @_;
    my $file  = $self->get_file($key);
    my %attrs = $self->_parse_file( $file );
    %attrs = ( %attrs, %new_attrs );

    # TODO Line folding
    return $file->spew_utf8(
        join( "\n", map { $_ . ': ' . $attrs{$_} } keys %attrs ) );
}

sub search {
    my ( $self, $props, $term ) = @_;
    local ( @ARGV, $_ ) = $self->base_dir->children;
    return if !@ARGV;
    my @matches;
    while (<>) {
        s/^(\S+?):\s+//;
        if (/$term/o) {
            push @matches, $ARGV;
            close ARGV;
            next;
        }
    }
    return c(@matches)->map('basename')->uniq->to_array;
}
1;
