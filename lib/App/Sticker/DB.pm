package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(encode_json decode_json);

has dir_name => ( is => 'ro', required => 1 );
has dir => ( is => 'lazy' );

sub Mojo::URL::TO_JSON {
    shift->to_string;
}

sub Mojo::ByteStream::TO_JSON {
    my $stream = shift;
    return $stream->to_string;
}

sub _build_dir {
    my $self = shift;
    my $file = path( $self->dir_name );
    $file->mkpath();
    return $file;
}

sub get {
    my ( $self, @keys ) = @_;
    my $store = $self->_get_store;
    return @$store{@keys};
}

sub delete {
    my ( $self, @keys ) = @_;
    my $store = $self->_get_store;
    delete @$store{@key};
    return $self->save_store($store);
}

sub set {
    my ( $self, @docs ) = @_;
    my $store = $self->_get_store;
    for my $doc ( @docs ) {
	    my $key   = $doc->{url};
	    next unless $key;
	    $store->{$key} = $doc;
    }
    return $self->_save_store($store);
}

sub _get_store {
    my ($self) = @_;
    my $store;
    my $file = $self->dir->child('db.json');
    if ( $file->exists ) {
        $store = decode_json( $file->slurp );
    }
    else {
        $store = {};
    }
    return $store;
}

sub _save_store {
    my ( $self, $store ) = @_;
    return $self->dir->child('db.json')->spew( encode_json($store) );
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
