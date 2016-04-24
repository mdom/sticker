package App::Sticker::Commands::delete;
use Mojo::Base 'App::Sticker::Command';

has 'ids';

sub run {
    my ($self) = @_;
    my @ids = @{ $self->ids || [] };
    my $tx = $self->db->begin;
    $self->db->query( 'delete from urls where url_id = ?', $_ ) for @ids;
    $tx->commit;
    return 0;
}

1;
