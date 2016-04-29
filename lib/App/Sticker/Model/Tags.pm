package App::Sticker::Model::Tags;
use Mojo::Base -base;

has 'db';

sub tag_urls {
    my ( $self, $tag, @url_ids ) = @_;
    my $tx = $self->db->begin;
    $self->db->query( 'insert or ignore into tags ( name ) values ( ? )',
        $tag );
    my $id =
      $self->db->query( 'select tag_id from tags where name = ?', $tag )
      ->hash->{tag_id};

    $self->db->query(
        'insert or ignore into tags_urls ( tag_id, url_id) values (?, ?)',
        $id, $_ )
      for @url_ids;
    $tx->commit;
    return;
}

1;
