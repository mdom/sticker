package App::Sticker::Commands::source::delete;
use Mojo::Base 'App::Sticker::Command';

has 'file';

sub run {
    my $self = shift;
    $self->db->query( 'delete from sources where location = ?', $self->file );
    return 0;
}

1;
