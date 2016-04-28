package App::Sticker::Commands::source::list;
use Mojo::Base 'App::Sticker::Command';
use Mojo::Util 'tablify';

sub run {
    my $self = shift;
    print tablify(
        $self->db->query('select location, last_checked from sources')
          ->arrays->to_array );
    return 0;
}

1;
