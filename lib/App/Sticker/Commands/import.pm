package App::Sticker::Commands::import;
use Mojo::Base 'App::Sticker::Command';
use Path::Tiny;

has 'files';

sub run {
    my $self = shift;
    $self->import_html( 0, @{ $self->files } );
    my $delay = $self->ua->start;
    $delay->wait if $delay;
    return 0;
}

1;
