use strict;
use warnings;

use Test::More;

use Config qw(%Config);
use Data::Dumper;
use File::Basename;
use File::Path qw/ make_path /;
use File::Spec::Functions;
use File::Temp qw/ tempdir /;
use FindBin;

$ENV{HARNESS_VERBOSE} = 1;

my $find      = catfile( qw(blib script find) );
my $find2perl = find_find2perl();

unless( defined $find2perl ) {
	diag( <<"HERE" );
Did not find find2perl. This comes with the App::find2perl module
but some testing systems do not fully install prerequisites. The
find2perl script may be missing. Until we figure out how to track
down its location, we'll skip these tests on this system.
HERE

	pass( "Null pass" );
	done_testing();
	exit;
	}

diag( "find2perl is at <$find2perl>" );


subtest check_find2perl => sub { check_find2perl( $find2perl ) };
subtest check_find      => \&check_find;

my $dir = tempdir('perlpowertools-find-XXXXXXXX', TMPDIR => 1, CLEANUP => 1);
ok(-d $dir, "Created temp dir: $dir");

{
my @file_paths = map catfile( $dir, $_ ), qw[
	a/b/c/20.txt
	d/40.txt
	e/f/60.txt
	g/h/i/80.txt
	];

my $files;
subtest create_files => sub {
	$files = create_files( @file_paths );
	};

diag( "Files are\n " . join( "\n ", map { @$_ } @$files ) );

sub show_times {
	foreach my $file ( @file_paths ) {
		diag sprintf "%s  a:%d  m:%d",
			$file,
			(stat $file)[8,9]
		}
	}

subtest 'all_files' => sub {
	show_times();
	my $options = "$dir -type f";
	my $command = "$^X $find $options";

	my $got = join "", sort `$command`;
	my $expected = join "\n", sort map { @$_ } @$files;
	$expected .= "\n";
	my $rc = is( $got, $expected, "Found files with `$command`" );

	unless( $rc ) {
		diag( "!!! Command: $command" );
		diag( "!!! Got:\n$got" );
		diag( "!!! Expected:\n\t", Dumper($files) );
		}
	};

my $i = 0;
foreach my $args ( [qw(amin -50)], [qw(mmin +50)] ) {
	subtest $args->[0] => sub { min_test( @$args, $files->[$i++] ) };
	}
}

done_testing();

sub find_find2perl {
	my @candidates =
		grep { -e }
		map { catfile( $_, 'find2perl' ) }
			dirname($Config{perlpath}),
			split( /$Config{path_sep}/, $ENV{PATH} ),

			;

	push @candidates, catfile( $ENV{PERL_LOCAL_LIB_ROOT}, 'bin', 'find2perl' )
		if defined $ENV{PERL_LOCAL_LIB_ROOT};

	return defined $candidates[0] ? $candidates[0] : ();
	}

sub check_find2perl {
	my( $find2perl ) = @_;

	ok( -e $find2perl, "find2perl exists at $find2perl" );
	ok( -x $find2perl, "find2perl is executable $find2perl" );

	my $output = `$^X -c $find2perl 2>&1`;
	like( $output, qr/syntax OK/, "$find2perl compiles" );
	}

sub check_find {
   ok( -e $find, "find exists at $find" );
   ok( -x $find, "find is executable $find" );

   my $output = `$^X -c $find 2>&1`;
   like( $output, qr/syntax OK/, "$find compiles" );
   }

sub create_files {
	my $pivot = 50;
	my @files;

	for my $file ( @_ ) {
		subtest "create_$file" => sub {
			my $path = dirname( $file );

			make_path($path);
			ok(-d $path, "Created path: $path");

			open my $fh, '>', $file; close $fh;
			ok(-e $file, "Created file: $file");

			my( $minutes ) = $file =~ /(\d+)\.txt$/;

			push @{ $files[$minutes > $pivot ? 1 : 0] }, $file;

			my $time = time - 60 * $minutes;
			ok( utime($time, $time, $file), "Set <$file> file time to $minutes minutes ago" );
			};
		}

	\@files;
	}

sub min_test () {
	my( $arg, $time, $files ) = @_;
	show_times();

	my $options = "$dir -type f -$arg $time";
	my $command = "$^X $find $options";

	my $got = join '', sort `$command`;
	my $expected = join "\n", @$files, '';
	my $rc = is( $got, $expected, "Found files with `$command`" );

	unless( $rc ) {
		diag( "!!! Command: $command" );
		diag( "!!! Got:\n$got" );
		diag( "!!! Expected:\n\t", $expected );
		}
	}


__END__
