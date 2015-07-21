package App::Sticker::Modifier;
use Moo::Role;

after execute => sub {
    my $self = shift;
    $self->base->db->save;
    return;
};

1;
