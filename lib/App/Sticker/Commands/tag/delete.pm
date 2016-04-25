package App::Sticker::Commands::tag::delete;
use Mojo::Base 'App::Sticker::Command';
use Mojo::Collection 'c';

has [qw(bookmarks tag)];

sub run {
    my $self = shift;
    my $tx   = $self->db->begin;
    my $id =
      $self->db->query( 'select tag_id from tags where name = ?', $self->tag )
      ->hash->{tag_id};
    $self->db->query( 'delete from tags_urls where tag_id = ? and url_id = ?',
        $id, $_ )
      for @{ $self->bookmarks };
    $self->db->query(
'delete from tags where name = ? and not exists ( select 1 from tags_urls join tags using ( tag_id ) where name = ? )',
        $self->tag, $self->tag
    );
    $tx->commit;
    return 0;
}

1;
