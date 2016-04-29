package App::Sticker::Commands::source::update;
use Mojo::Base 'App::Sticker::Command';

sub run {
    my $self = shift;
    my $time = time;
    my $sources =
      $self->db->query('select location, last_checked from sources')->hashes;
    for my $source (@$sources) {
        $self->import_html( $source->{last_checked}, $source->{location} );
    }
    my $delay = $self->ua->start;
    $delay->wait if $delay;
    $self->db->query( 'update sources set last_checked = ?', $time );
    return 0;
}

1;
