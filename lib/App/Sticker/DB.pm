package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::URL;
use List::Util 'first';
use Time::Piece;

has db_file => ( is => 'ro', required => 1 );
has store => ( is => 'lazy' );
has dirty => ( is => 'rw', default => sub { 0 });
has backup => ( is => 'rw', default => sub { 1 });

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
    my @docs;
    for my $key (@keys) {
        my $doc = $self->store->{$key};
        next unless $doc;
        $doc->{_db_orig_key} = $key;
        push @docs, $doc;
    }
    return wantarray ? @docs : $docs[0];
}

sub map {
	my ($self,$code) = @_;
	for my $doc ( values %{$self->store} ) {
		local $_ = $doc;
		eval $code;
		die "$@\n" if $@;
		$self->set($doc);
	}
	return;
}

sub delete {
    my ( $self, @keys ) = @_;
    my @deleted = delete @{$self->store}{@keys};
    $self->dirty(1) if @deleted;
    return wantarray ? @deleted : $deleted[-1];
}

sub set {
    my ( $self, @docs ) = @_;
    $self->dirty(1) if @docs;
    for my $doc (@docs) {
        my $key = $doc->{url};
        next unless $key;
        my $orig_key = delete $doc->{_db_orig_key};
        if ( $orig_key and $key ne $orig_key ) {
            delete $self->store->{$orig_key};
        }
        $self->store->{$key} = $doc;
    }
    return;
}

sub save {
    my ($self) = @_;
    if ( $self->dirty ) {
	$self->db_file->copy($self->db_file . ".bak");
        return $self->db_file->spew( encode_json( $self->store ) );
    }
    return;
}

sub keys {
    my ($self) = @_;
    return keys %{ $self->store };
}

sub search {
    my ( $self, @terms ) = @_;
    my @matches;
    my $matcher = $self->compile_search(@terms);
    for my $doc ( values %{$self->store} ) {
        if ( $matcher->($doc) ) {
            push @matches, $doc;
        }
    }
    return @matches;
}

sub parse_date {
	my $string = shift;
	my $t;
	my @formats = ( '%Y%m%d' );
	for my $format ( @formats ) {
		$t = Time::Piece->strptime($string,$format);
		return $t if $t;
	}
	return;
}

sub match_property {
    my ( $hr, $prop, $matcher ) = @_;
    return unless exists $hr->{$prop};
    if ( ref $hr->{$prop} eq 'ARRAY' ) {
        return first { /$matcher/io } @{ $hr->{$prop} };
    }
    if ( $prop eq 'add_date' ) {
	    $matcher =~ s/^([<>=])?(.*)/$2/;
	    my $comparison = $1;
	    my $added = localtime($hr->{add_date});
	    return unless $added;
	    $matcher   = parse_date($matcher);
	    return unless $matcher;

            if    ( not defined $comparison ) { return $added == $matcher }
            elsif ( $comparison eq '=' )      { return $added == $matcher }
            elsif ( $comparison eq '<' )      { return $added < $matcher }
            elsif ( $comparison eq '>' )      { return $added > $matcher }

	    return;
    }
    else {
        return $hr->{$prop} =~ /$matcher/i;
    }

    return;
}

sub compile_search {
    my ( $self, @terms ) = @_;
    my $sub = 'sub { my $hr = shift;';
    for (@terms) {
        if (/[()]/) {
            $sub .= " $_ ";
        }
        elsif (/or/i)  { $sub .= " || "; }
        elsif (/and/i) { $sub .= " && "; }
        elsif (/not/i) { $sub .= " ! "; }
        elsif (/([^:]+):(.*)/) {
            $sub .= qq[ match_property(\$hr,q{$1},q{$2}) ];
        }
        else {
            $sub .= qq[(]
              . qq[    match_property(\$hr,q{title},q{$_}) ]
              . qq[ or match_property(\$hr,q{url},q{$_}) ] . qq[)];
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
