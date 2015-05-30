package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Mojo::Collection 'c';
use Path::Tiny;
use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::URL;

has db_file => ( is => 'ro', required => 1 );
has store => ( is => 'lazy' );

sub Mojo::URL::TO_JSON {
    shift->to_string;
}

sub Mojo::ByteStream::TO_JSON {
    my $stream = shift;
    return $stream->to_string;
}

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $attrs = ref $args[0] eq 'HASH' ? $args[0] : {@args};
    if ( exists $attrs->{db_file} ) {
        $attrs->{db_file} = path( $attrs->{db_file} );
        return $attrs;
    }
}

sub _build_store {
    my ($self) = @_;
    my $store;
    my $file = path($self->db_file);
    if ( $file->exists ) {
        $store = decode_json( $file->slurp );
    }
    else {
        $store = {};
    }
    return $store;
}

sub get {
    my ( $self, @keys ) = @_;
    return @{$self->store}{@keys};
}

sub delete {
    my ( $self, @keys ) = @_;
    return delete @{$self->store}{@keys};
}

sub set {
    my ( $self, @docs ) = @_;
    for my $doc (@docs) {
        my $key = $doc->{url};
        next unless $key;
        $self->store->{$key} = $doc;
    }
    return;
}

sub save {
    my ( $self, $store ) = @_;
    return $self->db_file->spew( encode_json($self->store) );
}

sub search {
    my ( $self, $term ) = @_;
    my @matches;
    my $matcher = $self->compile_search($term);
    for my $doc ( values %{$self->store} ) {
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
            $sub .= qq[ 
	        return unless exists \$hr->{$1};
	        if ( ref \$hr->{$1} eq 'ARRAY' ) {
			return c( \@{\$hr->{$1}} )->first(q{$2})
		}
		else {
			\$hr->{$1} =~ q{$2}
		}
		];
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
