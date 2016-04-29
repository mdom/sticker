package App::Sticker::Commands::import;
use Mojo::Base 'App::Sticker::Command';
use Path::Tiny;

has 'files';

sub run {
    my $self = shift;
    $self->import_html( @{ $self->files } );
    $self->ua->start->wait;
    return 0;
}

1;
