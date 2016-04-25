package App::Sticker::Commands::tag::merge;
use Mojo::Base 'App::Sticker::Command';

has [qw(from_tag to_tag)];

sub run {
    my $self = shift;
    my $tx   = $self->db->begin;

    $self->db->query( 'insert or ignore into tags (name) values( ? )',
        $self->to_tag );

    $self->db->query( <<'EOF', $self->to_tag, $self->from_tag );
         update tags_urls
             set   tag_id = (select tag_id from tags where name = ? )
             where tag_id = (select tag_id from tags where name = ?);
EOF
    $self->db->query( 'delete from tags where name = ?', $self->from_tag );
    $tx->commit;
    return 0;
}

1;
