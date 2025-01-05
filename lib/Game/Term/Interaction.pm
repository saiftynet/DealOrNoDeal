use strict;
use warnings;
use Object::Pad;
=head2 Display
A Display object, draws and decorates items on a terminal window.
=cut

class Display{
	use Time::HiRes "sleep";
	field %colours=(black   =>30,red   =>31,green   =>32,yellow   =>33,blue   =>34,magenta   =>35,cyan  =>36,white   =>37,
               on_black=>40,on_red=>41,on_green=>42,on_yellow=>43,on_blue=>44,on_magenta=>45,on_cyan=>46,on_white=>47,
               reset=>0, bold=>1, faint=>2, italic=>3, underline=>4, blink=>5, strikethrough=>9, invert=>7, fast_blink=>6, no_blink=>25);
    field $buffer="\033[?c";
    field $dimensions  :param //={width=>80,height=>24};
    field $bigNum={1=>[" ▟ "," ▐ "," ▟▖"],
		           2=>["▞▀▖"," ▞ ","▟▄▖"],
		           3=>["▞▀▖"," ▀▖","▚▄▘"],
		           4=>[" ▟ ","▟▟▖"," ▐ "],
		           5=>["▛▀▘","▀▀▖","▚▄▘"],
		           6=>["▞▀▖","▙▄ ","▚▄▘"],
		           7=>["▀▀▌"," ▞ ","▞  "],
		           8=>["▞▀▖","▞▀▖","▚▄▘"],
		           9=>["▞▀▖","▝▀▌","▚▄▘"],
		           0=>["▞▀▖","▌ ▌","▚▄▘"],
		           "."=>["   ","   "," █ "],
		           " "=>["   ","   ","   "],
		           "L"=>["▗▚ ","▟▄ ","▟▄ "],
		           "p"=>["   ","▗▚ ","▐▘ "],
		           "?"=>["▞▀▖"," ▞ "," ▖ "],
			   };
	field $borders={	
		simple=>{tl=>"+", t=>"-", tr=>"+", l=>"|", r=>"|", bl=>"+", b=>"-", br=>"+",ts=>"|",te=>"|",},
		double=>{tl=>"╔", t=>"═", tr=>"╗", l=>"║", r=>"║", bl=>"╚", b=>"═", br=>"╝",ts=>"╣",te=>"╠",},
		shadow=>{tl=>"┌", t=>"─", tr=>"╖", l=>"│", r=>"║", bl=>"╘", b=>"═", br=>"╝",ts=>"┨",te=>"┠",},
		thin  =>{tl=>"┌", t=>"─", tr=>"┐", l=>"│", r=>"│", bl=>"└", b=>"─", br=>"┘",ts=>"┤",te=>"├",},  
		thick =>{tl=>"┏", t=>"━", tr=>"┓", l=>"┃", r=>"┃", bl=>"┗", b=>"━", br=>"┛",ts=>"┫",te=>"┣",}, 
	};
     
     BUILD{
		 print "\033[?25l"; # disable blinking cursor
	 }
=head3 style($style)
returns the Escape sequence that corresponds to an ANSI style
=cut	
    method style($style){
		return exists $colours{$style}?"\033[$colours{$style}m":"";
	}
	
=head3 decorate()
allows multiple style sequences.  these style formats may be passes either as
a comma separted string or an ArrayRef
=cut		
	method decorate($formats){
		my @fmts=ref $formats? @$formats :  split(",",$formats);
		my $dec="";
		foreach (@fmts){
			$dec.=exists $colours{$_}?"\033[$colours{$_}m":"";
		}
		return $dec
	}
	
=head3 paint($block,@formats)
	# multiple styles can used by either using a ref to a list of styles, or comma separated list
	# multiline strings is handled by either using a ref to a list of strings, or comma separated list
=cut
    method paint($block,$formats){ 
		return unless $block;
		my @strs=ref $block ? @$block  :  split("\n",$block);
		foreach (0..$#strs){
			$strs[$_]=$self->decorate($formats).$strs[$_]."\033[$colours{reset}m";
		}
		return ref $block?\@strs:join("\n",@strs);
	}
	
=head3 printAt($row,$column,$block)
 print a string to a cursor position
 multiline strings is handled by either using a ref to a list of strings, or comma separated list
=cut	
	method printAt($row,$column,$block){
		$block//="";
		my @strs=ref $block ? @$block  :  split("\n",$block);
		print "\033[".$row++.";$column"."H".$_ foreach (@strs);
        $|=1;
	}
	
=head3 clear()
 clears screens
=cut	
	method clear(){
		system($^O eq 'MSWin32'?'cls':'clear');
		$buffer="\033[?c";
	}
	
=head3 stripColours($str)
   clears a string of any colours escape codes
=cut	
	
	method stripColours($block){
		my @strs=ref $block ? @$block  :  split("\n",$block);
		foreach (0..$#strs){
			$strs[$_]=~s/\033\[[^m]+m//g
		}
        return  ref $block?\@strs:join("\n",@strs);
	}
	
=head3 blank($block)
   makes a block of text blanks (spaces),  the block may be passed as a 
   ref to array of strings or a string separated by newlines;
   returns block in same format
=cut	
	method blank($block){
		$block= $self->stripColours($block);
		my @strs=ref $block ? @$block  :  split("\n",$block);
		foreach (0..$#strs){
			$strs[$_]=" " x length($self->stripColours($strs[$_]));
		}
		return ref $block?\@strs:join("\n",@strs);
	}
	
=head3 flash($block,$row,$column,$interval,$number)
   flash a block alternating between block and its blank.
   the interval in microseconds and the number of flashes are required
   even number of flashes means block is does not persist, odd number 
   means that the block remains after flashing
=cut	
	
	method flash($block,$row,$column,$interval,$number){
		my $blank=$self->blank($block);
		for (0..$number){
			$self->printAt($row,$column,$_%2?$block:$blank);
			sleep $interval;
		}
	}

=head trimBlock($block,$start,$length)
  left and right crop block, padding if needed
=cut

    method trimBlock($block,$start,$length){
		my @strs=ref $block ? @$block  :  split("\n",$block);
		foreach my $row (0..$#strs){
			$strs[$row]=substr($strs[$_],$start,$length);
			$strs[$row].=" " x ($length-length($strs[$row]));
		};
		return ref $block?\@strs:join("\n",@strs);
	}

	
=head3 largeNum($number)
prints a large version of the text (and currencies only)
=cut	
	method largeNum($number){
		my $lot=["","",""];
		foreach my $digit  (split //, $number){
			$digit="?" unless $bigNum->{$digit};  # if character doesnt exist
			foreach(0..2){
				$lot->[$_].=$bigNum->{$digit}->[$_]
			}
		}
		return $lot;
	}
	
	method center{
		my ($block,$minColumn,$maxColumn)=@_;
		unless ($minColumn || $maxColumn){
			$minColumn=0;
			$maxColumn=$dimensions->{width}; # change later to screenwidth
		}
		unless ($maxColumn){
			$maxColumn=$minColumn;
			$minColumn=0;
		}
		return if ($minColumn>$maxColumn) ;
		
		
	}
	
	method box{
		my %params=ref $_[0]?%$_[0]:@_;
		my $content =$params{content}//[""];  # $content converted to arrayRef
		$content=[split "\n",$content] unless (ref $content);
		my $width=$params{width}//$self->blockWidth($content);
		my $height=$params{height}//$self->blockHeight($content);
		$content=[@$content[0..$height-1]];
		$content=$self->trimBlock($content,0,$width);
		my %border=$borders->{$params{style}//"simple"};
		my @blck=($border{tl}.($border{t}x$width).$border{tr});
		for (0..$height-1){
			push @blck,$border{l}.(defined $content->[$_]?$content->[$_]:" "x$width).$border{r};
		}
		push @blck,$border{bl}.($border{t}x$width).$border{br};          
		return [@blck];
	}

}


=head2 UI
An Interaction Object handles interactions with the Terminal

=cut

class UI{   
#######################################################################################
#####################   User Interaction Object #######################################
#######################################################################################

    field $update=1;
    field $window :reader ={width=>80,height=>24};
    field $stty;
    field $mode :writer :param //="default";
    field $buffer="";
    field $run;
    field $namedKeys={};
    field $actions={};
    field $mapping;
    field $repeat=0;
    field $debug=0;
    field $quitKey;
        
    BUILD{
		$namedKeys={
        32     =>  'space',
        13     =>  'return',
        9      =>  'tab',
        '[Zm'  =>  'shifttab',
        '[Am'  =>  'uparrow',
        '[Bm'  =>  'downarrow',
        '[Cm'  =>  'rightarrow',
        '[Dm'  =>  'leftarrow',
        '[Hm'  =>  'home',
        '[2~m' =>  'insert',
        '[3~m' =>  'delete',
        '[Fm'  =>  'end',
        '[5~m' =>  'pageup',
        '[6~m' =>  'pagedown',
        '[Fm'  =>  'end',
        'OPm'  =>  'F1',
        'OQm'  =>  'F2',
        'ORm'  =>  'F3',
        'OSm'  =>  'F4',
        '[15~m'=> 'F5',
        '[17~m'=> 'F6',
        '[18~m'=> 'F7',
        '[19~m'=> 'F8',
        '[21~m'=> 'F10',
        '[24~m'=> 'F12',
    };    
    
        
        $SIG{WINCH} = sub {$self->winSizeChange()};
    
        $stty = `stty -g`;  # save old stty settings
        chomp($stty);
	}
    
    method run($runMode){
		$mode=$runMode if $runMode;
		$run=1;
		return unless $actions->{$mode};
		$self->get_terminal_size();
		binmode(STDIN);
		$self->ReadMode(5);
		my $key;
		    while ($run) {
				last if ( !$self->dokey($key) );
				$actions->{$mode}->{updateAction}?$actions->{$mode}->{updateAction}->() : $self->updateAction() if ($update); # update screen
				$update=1;
				$key = $self->ReadKey();
			}
		#$self->ReadMode(0);
		print "\n";
	}
    
  method repeat($rep){   # enable or disable keyboard repeat
		$rep//=$repeat?0:1; # if not specified toggle the repeat
		for ($rep){
			/on|1/i && do{
				`xset r on`;
				$repeat=1;
				last;
			};
			/off|0/i && do{
				`xset r off`;
				$repeat=0;
				last;
			};
		}
	}

	method stop{
		$run=0;
		$| = 1;
		`xset r on`;
		$self->ReadMode(0);  # restore old tty
	}
	
	method dokey($key) {
       return 1 unless (defined $key);
       my $ctrl = ord($key);my $esc="";
       return if ($ctrl == 3);                 # Ctrl+c = exit;
       my $pressed="";
       if ($ctrl==27){
         while ( my $key = $self->ReadKey() ) {
           $esc .= $key;
           last if ( $key =~ /[a-z~]/i );
         }
         if ($esc eq "O"){# F1-F5
            while ( my $key = $self->ReadKey() ) {
             $esc .= $key;
             last if ( $key =~ /[a-z~]/i );
            }
          }    
         $esc.="m"
       };
       if    (exists $namedKeys->{$ctrl}){$pressed=$namedKeys->{$ctrl}}
       elsif (exists $namedKeys->{$esc}) {$pressed=$namedKeys->{$esc}}
       else  {$pressed= ($esc ne "")?$esc:chr($ctrl);};
       $self->act($pressed,$key);    
       return 1;
   }

# if action defined by mode and keypress, then do the action
# otherwise, key press  is entered into buffer
   method act($pressed,$key){ 
      if ($actions->{$mode}->{$pressed}){
        $actions->{$mode}->{$pressed}->();
      }
      else{
        $buffer.=$key;
      } 
    $self->stop() if ($quitKey && ($pressed eq $quitKey));
    print $pressed if $debug;
    $update=1;
  }

  method get_terminal_size {
    if ($^O eq 'MSWin32'){
        `chcp 65001\n`;
        my $geometry=(split("\n", `powershell -command "&{(get-host).ui.rawui.WindowSize;cls}"`))[3];
        ($window->{height}, $window->{width})=(split(/\s+/,$geometry))[1,2];
    }
    else{    
        ($window->{height},  $window->{width} ) = split( /\s+/, `stty size` );
         $window->{height} -= 2;
    }
    return $window;
  }

  method winSizeChange{
    $self->get_terminal_size();
    $actions->{$mode}->{"windowChange"}->() if $actions->{$mode}->{"windowChange"};
  }

  method setup($keyActions){
	foreach my $uiMode(keys %$keyActions){
		foreach my $k (keys %{$keyActions->{$uiMode}}){
				$self->setKeyAction($uiMode,$k,$keyActions->{$uiMode}->{$k});
		}
	}
  }

  method ReadKey {
    my $key = '';
    sysread( STDIN, $key, 1 );
    return $key;
  }

  method ReadLine { return <STDIN>;}
  
  method ReadMode($mode){
    if ( $mode == 5 ) {  
        system( 'stty', 'raw', '-echo' );# find Windows equivalent
    }
    elsif ( $mode == 0 ) {
	   die "Mode 0 called";
       # system( 'stty', $stty ); # find Windows equivalent
    }
  }

### actions to update the screen need to be setup for interactive applications 
  method setKeyAction($mode,$key,$uAction){
    $actions->{$mode}->{$key}=$uAction;
  }

  method updateAction{
    print "\n\r";
   }
}
