package App::Sticker::Commands::tag::add;
use Mojo::Base 'App::Sticker::Command';

has [qw(bookmarks tag)];

sub run {
    my $self = shift;
    $self->tags->tag_urls( $self->tag, @{ $self->bookmarks } );
    return 0;
}

1;
