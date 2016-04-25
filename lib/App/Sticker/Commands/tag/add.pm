package App::Sticker::Commands::tag::add;
use Mojo::Base 'App::Sticker::Command';
use Mojo::Collection 'c';

has [qw(bookmarks tag)];

sub run {
    my $self = shift;
    my $tx   = $self->db->begin;
    $self->db->query( 'insert or ignore into tags ( name ) values ( ? )',
        $self->tag );
    my $id =
      $self->db->query( 'select tag_id from tags where name = ?', $self->tag )
      ->hash->{tag_id};

    $self->db->query(
        'insert or ignore into tags_urls ( tag_id, url_id) values (?, ?)',
        $id, $_ )
      for @{ $self->bookmarks };
    $tx->commit;
    return 0;
}

1;
