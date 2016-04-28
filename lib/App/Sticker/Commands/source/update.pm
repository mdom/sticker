package App::Sticker::Commands::source::update;
use Mojo::Base 'App::Sticker::Command';

sub run {
    my $self = shift;
    my $time = time;
    my $sources =
      $self->db->query('select location, last_checked from sources')->hashes;
    my @files = map { $_->{location} } @$sources;
    $self->import_html(@files)->wait;
    $self->db->query( 'update sources set last_checked = ?', $time );
    return 0;
}

1;
