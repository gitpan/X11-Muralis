package X11::Muralis;
use strict;
use warnings;
use 5.8.3;

=head1 NAME

X11::Muralis - Perl module to display wallpaper on your desktop.

=head1 VERSION

This describes version B<0.01> of X11::Muralis.

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use X11::Muralis;

    my $obj = X11::Muralis->new(%args);

=head1 DESCRIPTION

The X11::Muralis module (and accompanying script, 'muralis') displays a
given image file on the desktop background (that is, the root window) of
an X-windows display.

This tries to determine what size would best suit the image; whether to
show it fullscreen or normal size, whether to show it tiled or centred
on the screen.  Setting the options overrides this behaviour.

One can also repeat the display of the last-displayed image, changing the
display options as one desires.

This uses the xloadimage program to display the image file.
This will display images from the directories given in the "path"
section of the .xloadimagerc file.

This also depends on xwininfo to get information about the root window.

=head2 The Name

The name "muralis" comes from the Latin "muralis" which is the word from
which "mural" was derived.  I just thought it was a cool name for a
wallpaper script.

=cut

use Image::Info;

=head1 METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    my %parameters = (
	config_dir => "$ENV{HOME}/.muralis",
	verbose => 0,
	fullscreen => 2,
	smooth => 2,
	center => 2,
	ext_match => qr/.(gif|jpeg|jpg|tiff|tif|png|pbm|xwd|pcx|gem|xpm|xbm)/i,
	@_
    );
    my $self = bless ({%parameters}, ref ($class) || $class);
    return ($self);
} # new

=head2 set

$dr->set(dir_match=>'animals');

$dr->set(verbose=>1);

$dr->set(verbose=>1, tile=>1);

Set values for this object.  These will be remembered for
when display_image is called.  See L<display_image> for
definitions of the arguments which can be used.

=cut
sub set {
    my $self = shift;
    # Interpret the arguments, if any.
    # They are a list of name => value pairs.
    # Don't bother checking; if they give meaningless arguments,
    # they will be ignored.
    while (@_)
    {
	my $name = shift;
	my $value = shift;
	$self->{$name} = $value;
    }
}

=head2 list_images

$dr->list_images();

$dr->list_images(dir_match=>'animals');

List all the images in the (matching) image directories.
(prints to STDOUT)

Optional argument: dir_match => I<string>

Limit the directories which are used to those which match the given string.

Note that if B<dir_match> is set here, then it remains set for later
methods unless it is explicitly set to an empty string.

=cut
sub list_images {
    my $self = shift;
    # Interpret the arguments, if any.
    # They are a list of name => value pairs.
    # Don't bother checking; if they give meaningless arguments,
    # they will be ignored.
    $self->set(@_);

    if ($self->{dir_match})
    {
	my $dir_name = $self->{dir_match};
	if (!defined $self->{_dirs}
	    || !$self->{_dirs})
	{
	    my @dirs = $self->get_dirs();
	    $self->{_dirs} = \@dirs;
	}
	my $dirs_ref = $self->{_dirs};

	my $count = 0;
	foreach my $dir (@{$dirs_ref})
	{
	    print "${dir}:\n";
	    my $command = "ls $dir";
	    open(LIN, "$command|") || die "Cannot pipe from $command";
	    while (<LIN>)
	    {
		# images match these extensions
		my $ext_match = $self->{ext_match};
		if (/$ext_match/)
		{
		    print $_;
		    $count++;
		}
	    }
	    close(LIN);
	}
	$count;
    }
    else # all
    {
	print `xloadimage -list`;
    }
}

=head2 count_images

my $count = $dr->count_images();

my $count = $dr->count_images(dir_match=>'animals');

Counts all the images in the (matching) image directories.

Optional argument: dir_match => I<string>

If image directories are defined, then limit the directories which are
used, to those which match the given string.

Note that if B<dir_match> is set here, then it remains set for later
methods unless it is explicitly set to an empty string.

=cut
sub count_images {
    my $self = shift;
    # Interpret the arguments, if any.
    # They are a list of name => value pairs.
    # Don't bother checking; if they give meaningless arguments,
    # they will be ignored.
    $self->set(@_);

    my $dir_name = $self->{dir_match};
    if (!defined $self->{_dirs}
	|| !$self->{_dirs})
    {
	my @dirs = $self->get_dirs();
	$self->{_dirs} = \@dirs;
    }
    my $dirs_ref = $self->{_dirs};

    my $count = 0;
    foreach my $dir (@{$dirs_ref})
    {
	my $command = "ls $dir";
	open(LIN, "$command|") || die "Cannot pipe from $command";
	while (<LIN>)
	{
	    # images match these extensions
	    my $ext_match = $self->{ext_match};
	    if (/$ext_match/)
	    {
		$count++;
	    }
	}
	close(LIN);
    }
    return $count;
} #count_images

=head2 display_image

=cut
sub display_image {
    my $self = shift;
    $self->set(@_);

    my $filename = '';
    if ($self->{random}) # get a random file
    {
	$filename = $self->get_random_file();
    }
    elsif ($self->{repeat_last}) # repeat the last image
    {
	my $cdir = $self->{config_dir};
	if (-f "$cdir/last")
	{
	    open(LIN, "$cdir/last") || die "Cannot open $cdir/last";
	    $filename = <LIN>;
	    close(LIN);
	    $filename =~ s/\n//;
	    $filename =~ s/\r//;
	}
    }
    if (!$filename)
    {
	$filename = $self->{filename};
    }

    my $options = $self->get_display_options($filename);
    my $command = "xloadimage -onroot $options $filename";
    print STDERR $command, "\n" if $self->{verbose};
    system($command);
    $self->save_last_displayed($filename);
} # display_image

=head1 Private Methods

=head2 get_dirs

my @dirs = $self->get_dirs();

my @dirs = $self->get_dirs(dir_match=>$match);

Asks xloadimage what it things the image directories are.
Filters these by dir_match if required.

=cut
sub get_dirs {
    my $self = shift;
    $self->set(@_);

    my @dirs = ();
    my $fh;
    open($fh, "xloadimage -configuration |") || die "can't call xloadimage: $!";
    while (<$fh>)
    {
	if (/Image path:\s(.*)/)
	{
	    @dirs = split(' ', $1);
	}
    }
    close($fh);
    if ($self->{dir_match})
    {
	my $dir_match = $self->{dir_match};
	my @mdirs = grep(/$dir_match/, @dirs);
	@dirs = @mdirs;
    }
    return @dirs;
} #get_dirs

=head2 get_root_info

Get info about the root window

=cut

sub get_root_info ($) {
    my $self = shift;

    my $verbose = $self->{verbose};

    my $width = 0;
    my $height = 0;
    my $depth = 0;

    my $fh;
    open($fh, "xwininfo -root |") || die "Cannot pipe from xwininfo -root";
    while (<$fh>)
    {
	if (/Width/)
	{
	    /Width:?\s([0-9]*)/;
	    $width = $1;
	}
	if (/Height/)
	{
	    /Height:?\s([0-9]*)/;
	    $height = $1;
	}
	if (/Depth/)
	{
	    /Depth:?\s([0-9]*)/;
	    $depth = $1;
	}
    }
    close($fh);
    if ($verbose)
    {
	print STDERR "SCREEN: width = $width, height = $height, depth = $depth\n";
    }
    $self->{_root_width} = $width;
    $self->{_root_height} = $height;
    $self->{_root_depth} = $depth;
}

=head2 find_nth_file

Find the full name of the nth file
uses dirs, dir_match

=cut

sub find_nth_file ($$) {
    my $self = shift;
    my $nth = shift;

    if (!defined $self->{_dirs}
	|| !$self->{_dirs})
    {
	my @dirs = $self->get_dirs();
	$self->{_dirs} = \@dirs;
    }
    my $dirs_ref = $self->{_dirs};
    my $dir_name = $self->{dir_match};

    my $full_name = '';
    my $count = 0;
    foreach my $dir (@{$dirs_ref})
    {
	my $command = "ls $dir";
	open(LIN, "$command|") || die "Cannot pipe from $command";
	while (<LIN>)
	{
	    my $entry = $_;
	    $entry =~ s/\n//;
	    # images match these extensions
	    my $ext_match = $self->{ext_match};
	    if (/$ext_match/)
	    {
		$count++;
		if ($count == $nth)
		{
		    $full_name = "$dir/$entry";
		    last;
		}
	    }
	}
	if ($full_name)
	{
	    last;
	}
	close(LIN);
    }
    return $full_name;
}

=head2 get_random_file

Get the name of a random file

=cut
sub get_random_file ($) {
    my $self = shift;

    my $total_files = $self->count_images();
    # get a random number between 1 and the number of files
    my $rnum = int(rand $total_files) + 1;

    my $file_name = $self->find_nth_file($rnum);

    if ($self->{verbose})
    {
	if ($self->{dir_match})
	{
	    print STDERR "picked image #${rnum} out of $total_files from ",
		$self->{dir_match}, "\n";
	}
	else
	{
	    print STDERR "picked image #${rnum} out of $total_files\n";
	}
    }

    return $file_name;
} # get_random_file

=head2 find_fullname

Find the full filename of an image file

=cut
sub find_fullname ($$) {
    my $self = shift;
    my $image_name = shift;

    if (!defined $image_name)
    {
	die "image name not defined!";
    }
    my $dir_name = $self->{dir_match};

    my $full_name = '';
    if (!defined $self->{_dirs}
	|| !$self->{_dirs})
    {
	my @dirs = $self->get_dirs();
	$self->{_dirs} = \@dirs;
    }
    my $dirs_ref = $self->{_dirs};

    # first check if it's local
    if (-f $image_name)
    {
	$full_name = $image_name;
    }
    else # go looking
    {
	foreach my $dir (@{$dirs_ref})
	{
	    if (!$dir_name || $dir =~ /$dir_name/) # dir matches
	    {
		my $command = "ls $dir";
		open(LIN, "$command |") || die "Cannot pipe from $command";
		while (<LIN>)
		{
		    my $entry = $_;
		    $entry =~ s/\n//;
		    # images match these extensions
		    my $ext_match = $self->{ext_match};
		    if (/$image_name/ # a match!
			&& /$ext_match/
		    )
		    {
			$full_name = "$dir/$entry";
			last;
		    }
		}
		close(LIN);
		if ($full_name)
		{
		    if (-f $full_name)
		    {
			last;
		    }
		    else # darn, reset
		    {
			$full_name = '';
		    }
		}
	    }
	}
    }
    return $full_name;
} # find_fullname

=head2 get_display_options

Use the options passed in or figure out the best default options.
Return a string containing the options.

=cut
sub get_display_options {
    my $self = shift;
    my $filename = shift;

    if (!defined $self->{_root_width}
	|| !$self->{_root_width})
    {
	$self->get_root_info();
    }
    my $options = '';

    my $fullname = $self->find_fullname($filename);
    my $info = Image::Info::image_info($fullname);
    if (my $error = $info->{error})
    {
	warn "Can't parse info for $fullname: $error\n";
	$self->{fullscreen} = 0 if $self->{fullscreen} == 2;
	$self->{smooth} = 0 if $self->{smooth} == 2;
	$self->{center} = 0 if $self->{center} == 2;
    }
    else
    {
	if ($self->{verbose})
	{
	    print STDERR "IMAGE: $filename",
		  " ", $info->{file_media_type}, " ",
		  $info->{width}, "x", $info->{height},
		  " ", $info->{color_type},
		  "\n";
	}
	if ($self->{fullscreen} == 2) # not set
	{
	    $self->{fullscreen} = 0; # default
		# If the width and height are more than half the width
		# and height of the screen, make it fullscreen
		# However, if the the image is a square, it's likely to be a tile,
		# in which case we don't want to expand it unless it's quite big
		if (
		    (($info->{width} == $info->{height})
		     && ($info->{width} > ($self->{_root_width} * 0.7)))
		    ||
		    (($info->{width} != $info->{height})
		     && ($info->{width} > ($self->{_root_width} * 0.5))
		     && ($info->{height} > ($self->{_root_height} * 0.5)))
		   )
		{
		    $self->{fullscreen} = 1;
		}
	}
	my $overlarge = ($info->{width} > $self->{_root_width}
			 || $info->{height} > $self->{_root_height});

	if ($self->{smooth} == 2)
	{
	    $self->{smooth} = 0; # default
		if ($self->{fullscreen})
		{
		    # if fullscreen is set, then check if we want smoothing
		    if (($info->{width} < ($self->{_root_width} * 0.6))
			|| ($info->{height} < ($self->{_root_height} * 0.6 )))
		    {
			$self->{smooth} = 1;
		    }
		}
	}
	# do we want it tiled or centred?
	if ($self->{center} == 2) # not set
	{
	    $self->{center} = 0; #default
		if (!$self->{fullscreen})
		{
		    # if the width and height of the image are both
		    # close to the full screen size, don't tile the image
		    if (($info->{width} > ($self->{_root_width} * 0.9))
			&& ($info->{height} > ($self->{_root_height} * 0.9))
		       )
		    {
			$self->{center} = 1;
		    }
		}
	}
    }

    $options .= " -tile" if $self->{tile};
    $options .= " -fullscreen -border black" if $self->{fullscreen};
    $options .= " -center" if $self->{center};
    $options .= " -smooth" if $self->{smooth};
    $options .= " -colors " . $self->{colors} if $self->{colors};
    $options .= " -rotate " . $self->{rotate} if $self->{rotate};
    $options .= " -zoom " . $self->{zoom} if $self->{zoom};
    return $options;
} # get_display_options

=head2 save_last_displayed

Save the name of the image most recently displayed.

=cut
sub save_last_displayed ($) {
    my $self = shift;
    my $filename = shift;

    if (!-d $self->{config_dir})
    {
	mkdir $self->{config_dir};
    }
    my $cdir = $self->{config_dir};
    open(LOUT, ">$cdir/last") || die "Cannot write to $cdir/last";
    print LOUT $filename, "\n";
    close LOUT;
} # save_last_displayed
=head1 REQUIRES

    Image::Info
    Test::More

=head1 INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

In order to install somewhere other than the default, such as
in a directory under your home directory, like "/home/fred/perl"
go

   perl Build.PL --install_base /home/fred/perl

as the first step instead.

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the script.

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}


=head1 SEE ALSO

perl(1).

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of X11::Muralis
__END__
