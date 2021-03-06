package Data::ObjectDriver::Driver::GearmanDBI;
use strict;
use warnings;

use base qw( Data::ObjectDriver );
use Data::ObjectDriver::Iterator;
use Storable();
use Digest::MD5;
use Data::Dumper;

__PACKAGE__->mk_accessors(qw( dbi client func driver_arg enabled_cb uniqify_cb ));

sub init {
    my $driver = shift;
    my %param  = @_;

    for my $key (keys %param) {
        $driver->$key($param{$key});
    }
}

sub search {
    my $driver = shift;
    my($class, $terms, $args) = @_;

    my $dbi = $driver->dbi;

    ## if Gearman shouldn't be used, fallback to the configured dbi driver
    return $dbi->search(@_)
        unless $driver->enabled_cb->(@_);

    my ($sql, $bind, $stmt) = $dbi->prepare_fetch($class, $terms, $args);
    my $results = $driver->_gearman_search($sql, $bind);

    ## Transform the array returned by gearman to the hash we expect to load
    ## in the object
    my $map    = $stmt->select_map;
    my @select = @{ $stmt->select };

    my $to_hash = sub {
        my $array = shift;
        my $hash;
        my $i = 0;
        for my $col (@select) {
            $hash->{ $map->{$col} } = $array->[$i++];
        }
        return $hash;
    };

    my $nt = $args->{no_triggers};
    my @objs = map { $dbi->load_object_from_rec($class, $_, $nt); }
               map { $to_hash->($_) }
               @$results;

    return wantarray
            ? @objs
            : Data::ObjectDriver::Iterator->new( sub { shift @objs } );
}

sub _gearman_search {
    my $driver = shift;
    my ($sql, $bind) = @_;

    my $uniqify = $driver->uniqify_cb || \&_md5sum;
    my $func    = $driver->func;
    my $uniq    = $uniqify->($sql, $bind);
    my $client  = $driver->client;

    my $res = $client->do_task( $func =>
        \Storable::nfreeze( {
            driver_arg => $driver->driver_arg,
            sql        => $sql,
            bind       => $bind,
            key        => $uniq,
        } ),
        {
            uniq => $uniq  # coalesce all requests for this data
        }
    );
    return $res ? Storable::thaw($$res) : [];
}

sub _md5sum {
    my ($sql, $bind) = @_;
    return Digest::MD5::md5_hex(join "", $sql, @$bind);
}

## every single data access methods are delegated to dbi
## except for search
sub lookup       { shift->dbi->lookup       (@_) }
sub lookup_multi { shift->dbi->lookup_multi (@_) }
sub exists       { shift->dbi->exists       (@_) }
sub insert       { shift->dbi->insert       (@_) }
sub replace      { shift->dbi->replace      (@_) }
sub update       { shift->dbi->update       (@_) }
sub remove       { shift->dbi->remove       (@_) }
sub fetch_data   { shift->dbi->fetch_data   (@_) }

## transactions are passed to dbi
sub add_working_driver { shift->dbi->add_working_driver (@_) }
sub commit             { shift->dbi->commit             (@_) }
sub rollback           { shift->dbi->rollback           (@_) }

## safety AUTOLOAD for the rest of non-core methods
sub DESTROY { }
sub AUTOLOAD {
    my $driver = shift;
    (my $meth = our $AUTOLOAD) =~ s/^.*:://;
    return $driver->dbi->$meth(@_);
}

1;
