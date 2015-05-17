package App::Sticker::DB;

use strict;
use warnings;
use feature "state";
use Moo;
use Mojo::Collection 'c';
use Mojo::ByteStream 'b';
use Tie::Array::CSV;

has file_name => ( is => 'ro', required => 1);
has tied_array => ( is => 'lazy' );

sub _build_tied_array {
	my $self = shift;
	return Tie::Array::CSV->new( $self->file_name, text_csv => { binary => 1 });
}

sub get {
    my ( $self, $key, @props ) = @_;
    my @order = qw( url title content );
    my ($index, $row) = $self->find($key);
    if ($row) {
	    my %attrs;
	    @attrs{@order} = @$row;
    }
    return;
}

sub delete {
    my ( $self, $key ) = @_;
    my ($index, $row ) = $self->find($key);
    if ( $row ) {
	    delete $self->tied_array->[$index];
    }
    return;
}

sub find {
	my ($self,$key) = @_;
	while  ( my ($index, $row) = each @{$self->tied_array} ) {
		if ($key eq $row->[0] ) {
			return $index, $row;
		}
	}
	return;
}

sub set {
    my ( $self, $key, %new_attrs ) = @_;
    my @order = qw( url title content );
    my ($index, $row) = $self->find($key);
    if ($row) {
	    my %attrs;
	    @attrs{@order} = @$row;
	    %attrs = ( %attrs, %new_attrs );
	    $row = @attrs{@order};
    }
    else {
	    push @{$self->tied_array}, [ map { b($_)->encode } @new_attrs{@order} ]
    }
    return;
}

sub search {
    my ( $self, $props, $term ) = @_;
    my @matches;
    for my $row ( @{$self->tied_array} ) {
    my @order = qw( url title content );
        my $values = join( ' ', @$row );
        if ( $values =~ /$term/o ) {
	    my %attrs;
	    @attrs{@order} = @$row;
            push @matches, \%attrs;
        }
    }
    return @matches;
}
1;
