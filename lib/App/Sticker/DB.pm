package App::Sticker::DB;

use strict;
use warnings;
use feature "state";
use open ':encoding(utf8)';
use Moo;
use Mojo::Collection 'c';
use Text::CSV;
use FileHandle;
use Path::Tiny;

has file_name => ( is => 'ro', required => 1 );
has csv       => ( is => 'lazy' );
has columns   => ( is => 'lazy' );

sub fh {
    my ( $self, $mode ) = @_;
    path($self->file_name)->touch();
    open( my $fh, $mode, $self->file_name )
      or die "Can't open database file " . $self->file_name . ": $!\n";
    return $fh;
}

sub _build_csv {
    my $self = shift;
    my $csv = Text::CSV->new( { binary => 1, eol => $/ } );
    $csv->column_names( $self->columns );
    return $csv;
}

sub _build_columns {
    return [qw( url title content )];
}

sub get {
    my ( $self, $key, @props ) = @_;
    my @order = qw( url title content );
    my $attrs = $self->find($key);
    if ($attrs) {
        return @{$attrs}{@props};
    }
    return;
}

sub edit_inplace {
    my ( $self, $mod_sub ) = @_;
    my $file = $self->file_name;
    rename( $file, "$file.bak" ) or die "Can't move $file to $file.bak: $!\n";
    open( my $old_fh, '<', "$file.bak" )
      or die "Can't open $file.bak: $!\n";
    my $new_fh = $self->fh('>');
    while ( my $hr = $self->csv->getline_hr($old_fh) ) {
        $hr = $mod_sub->($hr);
        if ( defined $hr ) {
            $self->csv->print_hr( $new_fh, $hr );
        }
    }
    return;
}

sub delete {
    my ( $self, @keys ) = @_;
    my %key_index = map { $_ => 1 } @keys;
    $self->edit_inplace(
        sub {
            my $hr = shift;
            if ( not exists $key_index{ $hr->{url} } ) {
                return $hr;
            }
            return;
        }
    );
    return;
}

sub find {
    my ( $self, $key ) = @_;
    my $fh = $self->fh('<');
    while ( my $hr = $self->csv->getline_hr($fh) ) {
        if ( $key eq $hr->{url} ) {
            return $hr;
        }
    }
    return;
}

sub set {
    my ( $self, $key, %new_attrs ) = @_;
    my @order = qw( url title content );
    my $attrs = $self->find($key);
    if ($attrs) {
        $self->edit_inplace(
            sub {
                my $hr = shift;
                if ( $key eq $hr->{url} ) {
                    return { %$hr, %new_attrs };
                }
                return $hr;
            }
        );
    }
    else {
        my $fh = $self->fh('>>');
        $self->csv->print_hr( $fh, \%new_attrs );
    }
    return;
}

sub search {
    my ( $self, $term ) = @_;
    my @matches;
    my $matcher = $self->compile_search($term);
    my $fh      = $self->fh('<');
    while ( my $hr = $self->csv->getline_hr($fh) ) {
        if ( $matcher->($hr) ) {
            push @matches, $hr;
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
