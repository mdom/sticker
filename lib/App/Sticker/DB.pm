package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Path::Tiny;
use JSON::MaybeXS;

has dir_name => ( is => 'ro', required => 1 );
has dir      => ( is => 'lazy' );
has json     => ( is => 'lazy' );

sub Mojo::URL::TO_JSON {
    shift->to_string;
}

sub Mojo::ByteStream::TO_JSON {
    my $stream = shift;
    return $stream->to_string;
}

sub _build_json {
    my $json = JSON::MaybeXS->new( pretty => 1, convert_blessed => 1 );
    return $json;
}

sub _build_dir {
    my $self = shift;
    my $dir  = path( $self->dir_name );
    $dir->mkpath();
    return $dir;
}

sub get {
    my ( $self, $key ) = @_;
    $key = b($key)->sha1_sum;
    my $doc;
    my $file = $self->dir->child($key);
    if ( $file->exists ) {
        $doc = $self->json->decode( $file->slurp_utf8 );
    }
    return $doc;
}

sub set {
    my ( $self, $doc ) = @_;
    my $key;
    if ( exists $doc->{url} ) {
        $key = b( $doc->{url} )->sha1_sum;
    }
    else {
        return;
    }
    return $self->dir->child($key)->spew_utf8( $self->json->encode($doc) );
}

sub search {
    my ( $self, $term ) = @_;
    my @matches;
    my $matcher = $self->compile_search($term);
    for my $file ( $self->dir->children ) {
        my $doc = $self->json->decode( $file->slurp_utf8 );
        if ( $matcher->($doc) ) {
            push @matches, $doc;
        }
    }
    return @matches;
}

sub compile_search {
    my ( $self, @terms ) = @_;
    my $sub = 'sub { my $hr = shift;';
    for (@terms) {
        if (/[()]/) {
            $sub .= " $_ ";
        }
        elsif (/or|and/i) {
            $sub .= " " . lc . " ";
        }
        elsif (/([^:]+):(.*)/) {
            $sub .= qq{ \$hr->{$1} =~ q{$2} };
        }
        else {
            die "Parse error (unknown token): $_\n";
        }
    }
    $sub .= '}';
    my $matcher = eval $sub;
    if ($@) {
        die "Compile error: $@\n";
    }
    return $matcher;
}

1;
