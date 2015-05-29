package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(encode_json decode_json);

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
    my $file = path( $self->dir_name );
    $file->mkpath();
    return $file;
}

sub get {
    my ( $self, $key ) = @_;
    my $store = $self->_get_store;
    return $store->{$key};
}

sub delete {
    my ( $self, $key ) = @_;
    my $store = $self->_get_store;
    delete $store->{$key};
    return $self->save_store($store);
}

sub set {
    my ( $self, $doc ) = @_;
    my $store = $self->_get_store;
    my $key   = $doc->{url};
    return unless $key;
    $store->{$key} = $doc;
    return $self->_save_store($store);
}

sub _get_store {
    my ($self) = @_;
    my $store;
    my $file = $self->dir->child('db.json');
    if ( $file->exists ) {
        $store = $self->json->decode( $file->slurp_utf8 );
    }
    else {
        $store = {};
    }
    return $store;
}

sub _save_store {
    my ( $self, $store ) = @_;
    return $self->dir->child('db.json')
      ->spew_utf8( $self->json->encode($store) );
}

sub search {
    my ( $self, $term ) = @_;
    my @matches;
    my $matcher = $self->compile_search($term);
    my $store   = $self->_get_store;
    for my $doc ( values %{$store} ) {
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
