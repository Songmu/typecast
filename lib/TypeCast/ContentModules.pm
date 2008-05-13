# $Id$
package TypeCast::ContentModules;
use strict;
use warnings;

use File::Basename;
use MT::Builder;
use TypeCast::Template::Context;

our ( @Modules, %ModulesByName, %ModulesByPortal, %ModuleCache );

## Compile all global modules in data/modules 
## in typecast/conf/environment.pl
#__PACKAGE__->compile_modules;

sub modules { \@Modules }

sub module { $ModulesByName{ $_[1] } }

sub modules_for_portal {
    my $class = shift;
    my($portal) = @_;
    [ @{ $ModulesByPortal{$portal} || [] }, @{ $ModulesByPortal{'all'} || [] } ];
}

sub module_labels { [ map { $_->{label} } @Modules ] }

sub load_modules {
    my $class = shift;
    my($data) = @_;
    push @Modules, @$data;
    for my $mod (@$data) {
        $ModulesByName{ $mod->{id} } = $mod;
        $class->classify_module(\%ModulesByPortal, $mod, $mod->{portal});
    }
}

sub classify_module {
    my $class = shift;
    my($hash, $module, $values) = @_;
    for my $val (split /\s+/, $values) {
        push @{ $hash->{$val} }, $module;
    }
}

sub refresh {
    my $class = shift;
    my($id) = @_;
    if ($id) {
## xxx fix
        #$Modules->{$id} = undef;
    } else {
        @Modules = ();
    }
}

sub module_order {
    my $class = shift;
    my($portal, $layout) = @_;
    my $order = $class->modules_for_portal($portal);
    return [ [ map $_->{id}, @$order ] ]
        if $layout eq 'one-column' or
           $layout eq 'two-column-left' or
           $layout eq 'two-column-right';

    return [] unless ($layout eq 'three-column');

    my @order_1;
    my @order_2;
    foreach my $m (@$order) {
        if    ($m->{sidebar} == 1) { push @order_1, $m->{id} }
        elsif ($m->{sidebar} == 2) { push @order_2, $m->{id} }
    }

    return [\@order_1, \@order_2];
}

sub compile_modules {
    my $class = shift;
    my($portal) = @_;
    my $dir = File::Spec->catdir($portal ?
     (TypeCore::Bootstrap->base, 'typecast', 'portal', $portal, 'data', 'modules',) :
     (TypeCore::Bootstrap->base, 'typecast', 'data', 'modules')
    );
    opendir(my $dh, $dir) or return 1;
    while (defined(my $file = readdir $dh)) {
        next unless $file =~ /\.tmpl$/;
        $class->compile_module($portal, File::Spec->catfile($dir, $file));
    }
    closedir $dh;
    1;
}

sub compile_module {
    my $class = shift;
    my($portal, $file) = @_;
    $portal ||= '_global';
    open my $fh, '<', $file
        or return $class->error("Can't open template file '$file': $!");
    my $c = do { local $/; <$fh> };
    my $mod = File::Basename::basename($file, '.tmpl');
    $ModuleCache{$portal}{$mod}{uncompiled} = $c;
    my $builder = MT::Builder->new;
    my $ctx = TypeCast::Template::Context->new;
    $ModuleCache{$portal}{$mod}{compiled} = $builder->compile($ctx, $c)
        or return $class->error($builder->errstr);
    1;
}

sub cached_module {
    my $class = shift;
    my($mod, $portal) = @_;
    $ModuleCache{$portal}{$mod} || $ModuleCache{'_global'}{$mod};
}

1;
