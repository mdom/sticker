package App::Sticker::Commands::delete;
use Mojo::Base 'App::Sticker::Command';

has 'ids';

sub run {
    my ($self) = @_;
    my @ids = @{ $self->ids || [] };
    ## TODO implement with in()
    $self->db->query('delete from urls where url_id = ?',$_) for @ids;
    return 0;
}

1;
