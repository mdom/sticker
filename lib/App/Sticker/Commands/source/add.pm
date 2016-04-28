package App::Sticker::Commands::source::add;
use Mojo::Base 'App::Sticker::Command';

has 'file';

sub run {
    my $self = shift;
    $self->db->query(
        'insert or ignore into sources (location, last_checked ) values (?, 0)',
        $self->file
    );
    return 0;
}

1;
