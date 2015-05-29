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
    my $file  = path( $self->dir_name );
    $file->mkpath();
    return $file;
}

sub get {
    my ( $self, $key ) = @_;
    my $docs;
    my $file = $self->dir->child($key);
    if ( $file->exists ) {
        $docs = $self->json->decode( $file->slurp_utf8 );
    }
    return $docs->{$key};
}

sub delete {
    my ( $self, $key ) = @_;
    $key = b($key)->sha1_sum;
    my $file = $self->dir->child($key);
    if ( $file->exists ) {
        return $file->remove;
    }
    return;
}

sub set {
    my ( $self, $doc ) = @_;
    my $key;
    if ( exists $doc->{url} ) {
        $key = $doc->{url};
    }
    else {
        return;
    }
    my $docs;
    my $file = $self->dir->child('db.json');
    if ( $file->exists ) {
        $docs = $self->json->decode( $file->slurp_utf8 );
    }
    else {
	$docs = {};
    }
    $docs->{$key} = $doc;
    return $self->dir->child('db.json')->spew_utf8( $self->json->encode($docs) );
}

sub search {
    my ( $self, $term ) = @_;
    my @matches;
    my $matcher = $self->compile_search($term);
    my $docs;
    my $file = $self->dir->child('db.json');
    if ( $file->exists ) {
        my $content = $file->slurp_utf8;
        $content = b($content)->encode;
        $docs    = decode_json( $content->to_string );
    }
    else {
        $docs = {};
    }
    for my $doc ( values %$docs ) {
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
