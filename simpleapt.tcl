#!/usr/bin/wish

# Open log file
set ::logf [open simpleapt.log w]

set ::CURX  0
set ::CURY  0
set ::CURZ  0

set ::SAFEZ  15.0
set ::PREVIOUS_LINE [list ]
set ::LIMIT_LINE none

set ::SIZEX 400.0
set ::SIZEY 400.0
set ::DOTX 5
set ::DOTY 5
set ::OFFSETX 100
set ::OFFSETY 100

set ::ARBITRARY_LINE_LENGTH 100.0
set ::PI 3.14159265358926

# Co-ords closer than this are treated as co-incident
set ::TOLERANCE 0.00001

set ::TOOLPATH_COLOUR red

# Line by line parsing
# Converted to lower case so case insensitive
# Everything else is ignored
# Patterns are searched in order, top to bottom so add more specific patterns before less specific

set ::PAT {
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+([0-9.-]+)[ ]+([0-9.-]+)"                                                                                                               procpoint           }
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+intersection[ ]+of[ ]+([a-z0-9_]+)[ ]+and[ ]+([a-z0-9_]+)"                                                                              procpointintersection2lines  }
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+intersection[ ]+of[ ]+line[ ]+([a-z0-9_]+)[ ]+and[ ]+circle[ ]+([a-z0-9_]+)"                                                            procpointintersectionlinecircle  }
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+point[ ]+([a-z0-9_]+)"                                                                                                                  procpointpoint  }
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+point[ ]+([a-z0-9_]+)"                                                                                                                  procpointpoint  }
    { "^[ ]*point[ ]+([a-z0-9_]+)[ ]+=[ ]+centre[ ]+of[ ]+circle[ ]+([a-z0-9_]+)"                                                                                                                  procpointcentreof  }
    
    { "^[ ]*line[ ]+([a-z0-9_]+)[ ]+=[ ]+through[ ]+([a-z0-9_]+)[ ]+and[ ]+([a-z0-9_]+)"                                                                                          procline2points     }
    { "^[ ]*line[ ]+([a-z0-9_]+)[ ]+=[ ]+through[ ]+([a-z0-9_]+)[ ]+at[ ]+angle[ ]+([0-9.-]+)([ ]*(degree|degrees))*"                                                             procline1pointatangle }
    { "^[ ]*line[ ]+([a-z0-9_]+)[ ]+=[ ]+([0-9.-]+)[ ]+([0-9.-]+)[ ]+([0-9.-]+)[ ]+([0-9.-]+)"                                                                                    procline            }
    { "^[ ]*line[ ]+([a-z0-9_]+)[ ]+=[ ]+parallel[ ]+to[ ]+([a-z0-9_]+)[ ]+distance[ ]+([0-9.-]+)[ ]+side[ ]+(left|right)"                                                        proclineparalleltoatdistance }

    { "^[ ]*circle[ ]+at[ ]+([0-9.-]+)[ ]+([0-9.-]+)[ ]+radius[ ]+([0-9.-]+)"                                                                                                     proccircleatwithradius }
    { "^[ ]*circle[ ]+([a-z0-9_]+)[ ]+=[ ]+tangent[ ]+to[ ]+([a-z0-9_]+)[ ]+and[ ]+([a-z0-9_]+)[ ]+radius[ ]+([0-9.-]+)[ ]+([a-z, ]*)"                                             proccircletangent2linesradius }

    { "^[ ]*arc[ ]+([a-z0-9_]+)[ ]+=[ ]+centre[ ]+([a-z0-9_]+)[ ]+start[ ]+([a-z0-9_]+)[ ]+end[ ]+([a-z0-9_]+)"                                                             procarccentretwopoints }

    { "^[ ]*intersection[ ]+([a-z0-9_]+)[ ]+of[ ]+()[ ]+and[ ]+()"                                                                                                                procintersection    }
    { "^[ ]*feed[ ]+([a-z0-9_]+)"                                                                                                                                                 procfeed            }
    { "^[ ]*tooldia[ ]+([a-z0-9_]+)"                                                                                                                                              proctooldia         }
    { "^[ ]*toolpath[ ]+([a-z0-9_]+)"                                                                                                                                             proctoolpath        }
    { "^[ ]*cutpath[ ]+([a-z0-9_]+)[ ]+with[ ]+z[ ]+from[ ]+([0-9.-]+)[ ]+to[ ]+([0-9.-]+)[ ]+step[ ]+([0-9.-]+)"                                                                 proccutpathwithz    }
    { "^[ ]*cutpath[ ]+([a-z0-9_]+)"                                                                                                                                              proccutpath         }
    { "^[ ]*limit[ ]+line[ ]+(before|on|after)[ ]+([a-z0-9_]+)"                                                                                                                   proclimitline       }
    { "^[ ]*start[ ]+at[ ]+([a-z0-9_]+)"                                                                                                                                          procstartat         }
    { "^[ ]*go[ ]+(right|left|on)[ ]+(to|along|direction)[ ]+([a-z0-9_]+)"                                                                                                        procgo              }
    { "^[ ]*go[ ]+z[ ]+([0-9._]+)"                                                                                                                                                procgoznum          }
    { "^[ ]*endpath"                                                                                                                                                              procendpath         }
    { "^[ ]*starttoolpath[ ]+([a-z0-9_]+)"                                                                                                                                        procstarttoolpath   }
    { "^[ ]*endtoolpath"                                                                                                                                                          procendtoolpath     }
    { "^[ ]*value[ ]+([a-z0-9_]+)[ ]*=[ ]*(.*)"                                                                                                                                   procvalue           }
}

set ::G_NAMES ""
set ::TOOLPATHS ""

proc findpat {} {

    set patname [lindex [info level -1] 0]
    puts "Pattern search"
    puts [info level -1]

    foreach pattern $::PAT {
	set pat       [lindex $pattern 0]
	set procname  [lindex $pattern 1]
	if { [string compare $patname $procname] == 0 } {
	    return $pat
	}
    }
    return ""
}

####################################################################################################

proc approx_equal {a b} {
    if { [expr abs($a-$b)] < $::TOLERANCE } {
	return 1
    }
    return 0

}

###############################################################################################

proc CanvasMouseWheel {c x y d} {
    $c scale all $x $y $d $d
}

set ::LAST_MOVE_VALID 0

proc CanvasMove {c x y} {
    if { $::LAST_MOVE_VALID } {
	set dx [expr $x-$::LAST_MOVE_X]
	set dy [expr $y-$::LAST_MOVE_Y]
	
	$c move all $dx $dy
    } else {
	set ::LAST_MOVE_X $x	
	set ::LAST_MOVE_Y $y
	set ::LAST_MOVE_VALID 1	
    }
}

set ::LAST_MOVE_X 0
set ::LAST_MOVE_Y 0

proc CanvasStartMove {c x y} {
    set ::LAST_MOVE_X [$c canvasx $x]
    set ::LAST_MOVE_Y [$c canvasy $y]
}

proc CanvasMove {c x y} {
    set x [$c canvasx $x]
    set y [$c canvasy $y]
    
    $c move all [expr $x-$::LAST_MOVE_X] [expr $y-$::LAST_MOVE_Y]
    set ::LAST_MOVE_X $x
    set ::LAST_MOVE_Y $y
}

proc CanvasStartScale {c x y} {
    set ::LAST_SCALE_X [$c canvasx $x]
    set ::LAST_SCALE_Y [$c canvasy $y]
}

proc CanvasScale {c x y} {
    set cx [$c canvasx $x]
    set cy [$c canvasy $y]
    
    if { $y > $::LAST_SCALE_Y } {
	set d 1.1
    } else {
	set d 0.9
    }

    $c scale all $x $y $d $d
    #set ::LAST_SCALE_X $x
    #set ::LAST_SCALE_Y $y
}

proc CreateCanvasWindow {name title} {

    set w $name
    catch {destroy $w}
    toplevel $w

    wm title $w $title

    set c $w.frame.c

    frame $w.frame -borderwidth .5c
    pack $w.frame -side top -expand yes -fill both

    scrollbar $w.frame.hscroll -orient horiz -command "$c xview"
    scrollbar $w.frame.vscroll -command "$c yview"

    canvas $c -relief sunken -borderwidth 2 -scrollregion {0 0 500 500}\
	-xscrollcommand "$w.frame.hscroll set" \
	-yscrollcommand "$w.frame.vscroll set"

    $c bind all <<MouseWheel>> "CanvasMouseWheel $c %D " 
    $c bind all <4> "CanvasMouseWheel $c %X %Y 0.7" 
    $c bind all <5> "CanvasMouseWheel $c %X %Y 1.3" 

    $c bind all <1> "CanvasStartMove $c %X %Y"
    $c bind all <B1-Motion> "CanvasMove $c %X %Y"
    $c bind all <3> "CanvasStartScale $c %X %Y"
    $c bind all <B3-Motion> "CanvasScale $c %X %Y"

    pack $w.frame.hscroll -side bottom -fill x
    pack $w.frame.vscroll -side right -fill y
    pack $c -expand yes -fill both
}

proc ExpandScrollRegion {c x1 y1 x2 y2} {

    #Make sure that the region is really expanded

    set sr [$c cget -scrollregion]

    set ox1 [lindex $sr 0]
    set oy1 [lindex $sr 1]
    set ox2 [lindex $sr 2]
    set oy2 [lindex $sr 3]

    if { $ox2 > $x2 } {
	set x2 $ox2
    }

    if { $oy2 > $y2 } {
	set y2 $oy2
    }

    if { $ox1 < $x1 } {
	set x1 $ox1
    }

    if { $oy1 < $y1 } {
	set y1 $oy1
    }

    $c configure -scrollregion "$x1 $y1 $x2 $y2"
}

#----------------------------------------------------------------------------------------------------

proc doerror {string} {
    puts "*** ERROR ****"
    puts $string
    exit
}

#----------------------------------------------------------------------------------------------------
# Cross product


proc cross_product {u v} {

    set u1 [lindex $u 0]
    set u2 [lindex $u 1]
    #    set u3 [lindex $u 2]
    set u3 0
    set v1 [lindex $v 0]
    set v2 [lindex $v 1]
    #    set v3 [lindex $v 2]
    set v3 0

    set s1 [expr $u2*$v3 - $u3*$v2]
    set s2 [expr $u3*$v1 - $u1*$v3]
    set s3 [expr $u1*$v2 - $u2*$v1]
    
    puts "cross product = $s1 $s2 $s3"
    return [list $s1 $s2 $s3]
}

# Magnitude of cross product
# We need a special proc fo rthis as it involves a 3D vector and we only have 2D vectors in the rest of the program
proc magnitude_of_cross_product {u v} {
    set cross [cross_product $u $v]

    return [magnitude_3d_vector $cross]
}

# Magnitude of a vector
proc magnitude {v} {
    set x [lindex $v 0]
    set y [lindex $v 1]

    return [expr sqrt($x*$x+$y*$y)]
}

proc magnitude_3d_vector {v} {
    set x [lindex $v 0]
    set y [lindex $v 1]
    set z [lindex $v 2]

    return [expr sqrt($x*$x+$y*$y+$z*$z)]
}

# Calculate a+b
proc add_vectors {a b} {
    set ax [lindex $a 0]
    set ay [lindex $a 1]
    set bx [lindex $b 0]
    set by [lindex $b 1]

    return [list [expr $ax+$bx] [expr $ay + $by]]
}

# Calculate a-b
proc subtract_vectors {a b} {
    set ax [lindex $a 0]
    set ay [lindex $a 1]
    set bx [lindex $b 0]
    set by [lindex $b 1]

    return [list [expr $ax-$bx] [expr $ay-$by]]
}

# Create a line from a vector and a point
# It's the line through the point in the direction of the vector

proc convert_vector_to_line {v p} {

    set i [lindex $v 0]
    set j [lindex $v 1]
    set x [lindex $p 0]
    set y [lindex $p 1]

    return [list $x $y [expr $x+$i] [expr $y+$j]]
}

# Convert a line to a vector
# Our canoniacl form for a line is any two points on that line

proc convert_line_to_vector {l} {
    set x1 [lindex $l 0]
    set y1 [lindex $l 1]
    set x2 [lindex $l 2]
    set y2 [lindex $l 3]

    return [list [expr $x2-$x1] [expr $y2-$y1]]
}

# Normalise a vactor

proc normalise_vector {v} {

    set mag [magnitude $v]
    set x [lindex $v 0]
    set y [lindex $v 1]

    return [list [expr $x / $mag] [expr $y / $mag]]
}

# Dot product

proc dot_product {u v} {
    set u1 [lindex $u 0]
    set u2 [lindex $u 1]
    set u3 [lindex $u 2]
    set u3 0
    set v1 [lindex $v 0]
    set v2 [lindex $v 1]
    set v3 [lindex $v 2]
    set v3 0

    return [expr $u1*$v1+$u2*$v2+$u3*$v3]
}

#----------------------------------------------------------------------------------------------------
#
# Angle between two lines
#

proc angle_between_lines {l1 l2} {
    # Calculate two vectors
    set v1 [convert_line_to_vector $l1] 
    set v2 [convert_line_to_vector $l2] 
    puts "v1 = $v1, v2=$v2"

    set magcross [magnitude_of_cross_product $v1 $v2]
    set dot [dot_product $v1 $v2]

    puts "Angle = atan($magcross / $dot)"
    return [expr atan($magcross/$dot)/$::PI*180]
}

#----------------------------------------------------------------------------------------------------
#
# Work out mx+c form of a line
#

proc convert_line_to_mxc {line} {

    set x1 [lindex $line 0]
    set y1 [lindex $line 1]
    set x2 [lindex $line 2]
    set y2 [lindex $line 3]

    if { $x1 == $x2 } {
	return [list ]
    }

    set m [expr ($y1-$y2)/($x1-$x2)]
    set c [expr $y1-$m*$x1]

    return [list $m $c]
}

#----------------------------------------------------------------------------------------------------
#
# Calculate the lines that bisect the angles between two other lines
#
# result 1 is acute angle line
# result 2 is obtuse angle line
#

proc lines_bisecting {l1 l2} {
    set v1 [convert_line_to_vector $l1] 
    set v2 [convert_line_to_vector $l2] 

    # Calculate two vectors that bisect the angles between these lines
    # We create a rhombus and the line through two opposing points is a bisector if the vectors have been normalised
    set nv1 [normalise_vector $v1]
    set nv2 [normalise_vector $v2]

    # Two answers 
    set b1 [add_vectors $nv1 $nv2]
    set b2 [subtract_vectors $nv1 $nv2]

    # Intersection point
    set int_pt [line_intersection $l1 $l2]

    # Return list of bisecting lines
    set bl1 [convert_vector_to_line $b1 $int_pt]
    set bl2 [convert_vector_to_line $b2 $int_pt]

    return [list $bl1 $bl2]
}

#----------------------------------------------------------------------------------------------------
# Scales a point for display on a canvas

proc scaleptx {x} {

    return [expr $::SCALEX*$x+$::OFFSETX]
}

proc scalepty {y} {

    return [expr $::SCALEY*$y+$::OFFSETY]
}

#----------------------------------------------------------------------------------------------------
#
# Removes duplicate points from a list of points
#

proc remove_duplicate_points {point_list} {

    puts "Removing duplicate points from $point_list"
    foreach pointa $point_list {
	set tx [lindex $pointa 0]
	set ty [lindex $pointa 1]

	# Count how many times the point is in the list. After once, remove any that are found
	set found 0
	set new_list ""

	foreach pointb $point_list {
	    set x [lindex $pointb 0]
	    set y [lindex $pointb 1]

	    if { [approx_equal $tx $x] && [approx_equal $ty $y] } {
		if { !$found } {
		    lappend new_list $pointb
		}
		set found 1
	    } else {
		lappend new_list $pointb
	    }

	}
	# Continue with pruned list
	set point_list $new_list
    }

    puts "      result-> $point_list"
    return $point_list
}

#----------------------------------------------------------------------------------------------------

# Given two points on each line, return co-ords of intersection
# returns null list if no intersection

proc line_intersection_points {x1 y1 x2 y2 x3 y3 x4 y4} {
    set det [expr ($x1-$x2)*($y3-$y4) - ($y1-$y2)*($x3-$x4)]
    puts "Intersection of ($x1,$y1)-($x2,$y3) and ($x3,$y3)-($x4,$y4)"
    puts  "det=$det"

    if { $det == 0 } {
	return [list ]

    }

    set ix [expr (($x1*$y2-$y1*$x2)*($x3-$x4)-($x1-$x2)*($x3*$y4-$y3*$x4))/$det]
    set iy [expr (($x1*$y2-$y1*$x2)*($y3-$y4)-($y1-$y2)*($x3*$y4-$y3*$x4))/$det]
    
    puts " I=>$ix $iy"

    if {0} {
	set w .intersection
	
	CreateCanvasWindow $w "Intersection"
	
	$w.frame.c create line [scaleptx $x1] [scalepty $y1] [scaleptx $x2] [scalepty $y2]
	$w.frame.c create line [scaleptx $x3] [scalepty $y3] [scaleptx $x4] [scalepty $y4]
	$w.frame.c create oval [expr [scaleptx $ix]-$::DOTX] [expr [scalepty $iy]-$::DOTY] [expr [scaleptx $ix]+$::DOTX] [expr [scalepty $iy]+$::DOTY]
    }
    
    return [list $ix $iy]
}

# Returns intersection point of two lines

proc line_intersection {line1 line2} {
    set x1 [lindex $line1 0]
    set y1 [lindex $line1 1]
    set x2 [lindex $line1 2]
    set y2 [lindex $line1 3]
    set x3 [lindex $line2 0]
    set y3 [lindex $line2 1]
    set x4 [lindex $line2 2]
    set y4 [lindex $line2 3]
    
    set intersection [line_intersection_points $x1 $y1 $x2 $y2 $x3 $y3 $x4 $y4]
    return $intersection
}

#----------------------------------------------------------------------------------------------------
#
# Is line horizontal?
#

proc is_line_horizontal {l} {

    set y1 [lindex $l 1]
    set y2 [lindex $l 3]

    if { $y1 == $y2 } {
	set horiz 1
    } else {
	set horiz 0
    }
    
    return $horiz   
}

proc is_line_vertical {l} {

    set x1 [lindex $l 0]
    set x2 [lindex $l 2]

    if { $x1 == $x2 } {
	set vert 1
    } else {
	set vert 0
    }
    
    return $vert   
}

#----------------------------------------------------------------------------------------------------
#
# returns intersection points (if any) of a line and a circle
#

proc intersection_line_circle {line circle} {

    puts "Line circle intersection"
    puts "line=$line, circle = $circle"

    # We move the problem so the circle is at (0,0), so the calculations are easier
    set cx      [lindex $circle 0]
    set cy      [lindex $circle 1]
    set radius  [lindex $circle 2]

    set x1 [lindex $line 0]
    set y1 [lindex $line 1]
    set x2 [lindex $line 2]
    set y2 [lindex $line 3]

    set ox1 [expr $x1 - $cx]
    set oy1 [expr $y1 - $cy]
    set ox2 [expr $x2 - $cx]
    set oy2 [expr $y2 - $cy]

    set ocx 0
    set ocy 0

    set oline [list $ox1 $oy1 $ox2 $oy2]

    # Convert to mx+c form
    set mxc_line [convert_line_to_mxc $oline]
    
    if { [is_line_vertical $oline] } {
	# Simpler problem
	# We have to take account of approximate equalities
	set v [expr $radius*$radius - $ox1*$ox1]
	
	if { [approx_equal $v 0] } {
	    set v 0
	}
	set oiy1 [expr sqrt($v)]
	set oiy2 [expr -$oiy1]
	
	# Translate back from origin to problem position
	set iy1 [expr $oiy1 + $cy]
	set iy2 [expr $oiy2 + $cy]

	# Build list of two points
	set p1 [list $x1 $iy1]
	set p2 [list $x1 $iy2]

	puts "vertical line"
	return [remove_duplicate_points [list $p1 $p2]]
    }

    if { [is_line_horizontal $oline] } {
	# Simpler problem
	set v [expr $radius*$radius - $oy1*$oy1]
	if { [approx_equal $v 0] } {
	    set v 0
	}
	
	set oix1 [expr sqrt ($v)]
	set oix2 [expr -$oix1]

	# Translate back from origin to problem position
	set ix1 [expr $oix1 + $cx]
	set ix2 [expr $oix2 + $cx]

	# Build list of two points
	set p1 [list $ix1 $y1]
	set p2 [list $ix2 $y1]

	puts "horizontal line"
	return [remove_duplicate_points [list $p1 $p2]]
    }

    # Work out the more complicated solution where the line is angled
    # Problem is in quadratic form, use formula to work out answers
    set m [lindex $mxc_line 0]
    set c [lindex $mxc_line 1]

    set qa [expr 1.0+$m*$m]
    set qb [expr 2.0*$m*$c]
    set qc [expr $c*$c - $radius*$radius]

    puts "m=$m, c=$c, a=$qa, b=$qb, c=$qc"

    # See if there is a real solution
    set det [expr $qb*$qb-4.0*$qa*$qc]

    puts "det=$det"
    if { $det < 0 } {
	# No solutions
	puts "Line circle int : No solutions, det=$det"
	return [list]
    }

    # Work out solutions (for x)
    set oix1 [expr (-1.0*$qb+sqrt($det))/(2.0*$qa)]
    set oix2 [expr (-1.0*$qb-sqrt($det))/(2.0*$qa)]

    if { $oix1 == $oix2 } {
	# One solution
	set oiy1 [expr $m*$ix1+$c]

	# Move back to problem position
	set ix1 [expr $oix1+$cx]
	set iy1 [expr $oiy1+$cy]

	set p1 [list $ix1 $iy1]
	puts "One solution"
	return [list $p1]
    }

    # Two solutions
    set oiy1 [expr $m*$oix1+$c]
    set oiy2 [expr $m*$oix2+$c]

    # Move back to problem position
    set ix1 [expr $oix1+$cx]
    set iy1 [expr $oiy1+$cy]
    set ix2 [expr $oix2+$cx]
    set iy2 [expr $oiy2+$cy]

    set p1 [list $ix1 $iy1]
    set p2 [list $ix2 $iy2]

    geometry_store point CLIPT1 $p1
    geometry_store point CLIPT2 $p2

    puts "Two solutions"
    return [remove_duplicate_points [list $p1 $p2]]
}


# Get distance between two points
proc distance_between {x1 y1 x2 y2} {
    return [expr sqrt(($x1-$x2)*($x1-$x2)+($y1-$y2)*($y1-$y2))]
}

# Get a line parallel to the one passed in. Distance from line is d, side we are 
# on is left or right, with direction of line from A to B

proc get_line_parallel_to {ax ay bx by d rightleft} {
    # Check for horizontal or vertical lines, we have to handle them differently
    if { $ay == $by } {
	# Horizontal line

	# left/right give different answers 
	switch $rightleft {
	    on {
		set mul 0
	    }
	    left {
		if { $ax < $bx } {
		    set mul 1
		} else {
		    set mul -1
		}
	    }
	    right {
		if { $ax < $bx } {
		    set mul -1
		} else {
		    set mul 1
		}
	    }
	}

	set rax $ax
	set ray [expr $ay+$d*$mul]
	set rbx $bx
	set rby [expr $by+$d*$mul]
    } elseif { $ax == $bx } {
	# vertical line

	# left/right give different answers 

	switch $rightleft {
	    on {
		set mul 0
	    }
	    left {
		if { $ay < $by } {
		    set mul 1
		} else {
		    set mul -1
		}
	    }
	    right {
		if { $ay < $by } {
		    set mul -1
		} else {
		    set mul 1
		}
	    }
	}

	set rax [expr $ax+$d]
	set ray $ay
	set rbx [expr $bx+$d]
	set rby $by
    } else {
	
	set dir_vec_x  [expr $bx - $ax]
	set dir_vec_x  [expr $by - $ay]
	
	# Intermediate value
	set w [expr -($by - $ay) / ($bx - $ax)]
	
	# left/right give different answers 
	switch $rightleft {
	    on {
		set mul 0
	    }
	    left {
		set mul 1
	    }
	    right {
		set mul -1
	    }
	}
	
	# Now work out what the tool offset vector is
	set tool_off_vec_y [expr ($d / sqrt ($w*$w + 1)) ]
	set tool_off_vec_x [expr ($w * $tool_off_vec_y) ]
	
	# Now ensure cross product has a positive z component This ensures it is consistently left or right
	set cross_product [cross_product [list [expr $bx - $ax] [expr $by - $ay] 0] [list $tool_off_vec_x $tool_off_vec_y 0]]
	
	if { [lindex $cross_product 2] < 0 } {
	    set tool_off_vec_x [expr $tool_off_vec_x * -1]
	    set tool_off_vec_y [expr $tool_off_vec_y * -1]
	}
	
	# Now apply left/right/on
	set tool_off_vec_x [expr $tool_off_vec_x * $mul]
	set tool_off_vec_y [expr $tool_off_vec_y * $mul]
	
	# Now add vector to end points to get points with tool offset
	set rax [expr $ax + $tool_off_vec_x]
	set ray [expr $ay + $tool_off_vec_y]
	set rbx [expr $bx + $tool_off_vec_x]
	set rby [expr $by + $tool_off_vec_y]
    }
    puts "Line parallel to $ax $ay $bx $by $d $rightleft => $rax $ray $rbx $rby"
    return [list $rax $ray $rbx $rby]
}

#----------------------------------------------------------------------------------------------------
#
# Creates a list of numbers from A to B in steps of S ensuring that the first and 
# last steps are present and do not exceed A..B

proc ab_to_list {a b s} {
    puts "$a .. $b    $s"

    # Ensure step value is in correct direction
    if { ($b > $a) && ($s < 0) } {
	set s [expr -1.0*$s]
    }

    if { ($b < $a) && ($s > 0) } {
	set s [expr -1.0*$s]
    }

    if { $b > $a } {
	for {set n $a} {$n <= $b} {set n [expr $n+$s]} {
	    lappend retval $n
	}
    }

    if { $b < $a } {
	for {set n $a} {$n >= $b} {set n [expr $n+$s]} {
	    lappend retval $n
	}
    }

    if { $n != $b } {
	lappend retval $b
    }
    foreach x $retval {
	puts "   $x"
    }
    puts $retval

    return $retval
}

#----------------------------------------------------------------------------------------------------

# Add a geometry item to database
proc geometry_store {type gname arglist} {
    # Add a new item or update an existing one
    if { [lsearch -exact $::G_NAMES $gname] == -1 } {
	lappend ::G_NAMES $gname
    }

    set ::G_DATA($gname) $arglist
    set ::G_TYPE($gname) $type
}

proc print_geometry_database {} {
    puts "\nGeometry Database\n"
    foreach item $::G_NAMES {
	puts "$item => $::G_DATA($item)"
    }
}

proc print_toolpaths {} {
    foreach toolpath $::TOOLPATHS {
	puts "$toolpath=>\n'$::TOOLPATH_TEXT($toolpath)'"
    }
}

proc find_geometry_item_data {name} {
    foreach item $::G_NAMES {
	if { [string compare $item $name] == 0 } {
	    return $::G_DATA($item)
	}
    }
    return none
}

proc find_geometry_item_type {name} {
    foreach item $::G_NAMES {
	if { [string compare $item $name] == 0 } {
	    return $::G_TYPE($item)
	}
    }
    return none
}

proc set_current_position {x y z} {
    # Set current position
    set ::CURX $x
    set ::CURY $y
    set ::CURZ $z
}

#----------------------------------------------------------------------------------------------------
#
# Variables, expressions and values
#

proc procvalue {line} {
    set pat [findpat]

    # Values are named expression results
    if { [regexp -- $pat $line all cname expression] } {
	# Modify the expression so all variables are correct Tcl 
	puts "Expr1 = '$expression'"
	#regsub -all {\$([a-z0-9_]+)} $expression "\$::VALUE(\\1)" expression
	puts "Expr2 = '$expression'"
	set ::VALUE($cname) [expr $expression]
    }

    # Returned text is added to output
    return "($cname = [expr $expression])\n"
}

proc print_value {} {

    puts [info level 0]
    puts ""
    foreach value [array names ::VALUE] {
	puts "$value = $::VALUE($value)"
    }
    puts ""
}


#----------------------------------------------------------------------------------------------------
#
# Point is a copy of another point
#

proc procpointpoint {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname pname] } {
	set p [find_geometry_item_data $pname]

	# Create a new point with the data of the first one
	geometry_store point $gname $p	
    }

    return ""
}

#----------------------------------------------------------------------------------------------------
#
# Point is centre of a circle
#

proc procpointcentreof {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname cname] } {
	set c [find_geometry_item_data $cname]

	# Create a new point that is the centre of the circle
	set x [lindex $c 0]
	set y [lindex $c 1]

	geometry_store point $gname "$x $y"	
    }

    return ""
}

#----------------------------------------------------------------------------------------------------

proc procpointintersectionlinecircle {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all gname l c modifiers] } {
	set line   [find_geometry_item_data $l]
	set circle [find_geometry_item_data $c]
	
	# Get intersections
	set intpts [intersection_line_circle $line $circle]
	
	# There's up to two points of intersection, we use modifiers to determine which ones to keep
	geometry_store_modifier_qualified_points $intpts $modifiers $gname null {list $x $y} {geometry_store point $gname$suffix $object}
	return ""
    }
    
    return "(**ERROR*** $line)"
}


#----------------------------------------------------------------------------------------------------

proc procpointintersection2lines {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname l1 l2] } {
	set line1 [find_geometry_item_data $l1]
	set line2 [find_geometry_item_data $l2]

	set x1 [lindex $line1 0]
	set y1 [lindex $line1 1]
	set x2 [lindex $line1 2]
	set y2 [lindex $line1 3]
	set x3 [lindex $line2 0]
	set y3 [lindex $line2 1]
	set x4 [lindex $line2 2]
	set y4 [lindex $line2 3]

	set intersection [line_intersection_points $x1 $y1 $x2 $y2 $x3 $y3 $x4 $y4]

	geometry_store point $gname $intersection
    }
    return ""
}

proc procpoint {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname gx gy] } {
	geometry_store point $gname "$gx $gy"
	puts "point: $gname $gx $gy"
    }
    return ""
}

proc procline {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname gx1 gy1 gx2 gy2 ] } {
	geometry_store line $gname "$gx1 $gy1 $gx2 $gy2"
	puts "line: $gname $gx1 $gy1 $gx2 $gy2"
    }
    return ""
}

#----------------------------------------------------------------------------------------------------
#
# Create arc with given centre and two points as start and end
#
proc procarccentretwopoints {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname centre start end ] } {
	# Get points
	set pcentre [find_geometry_item_data $centre]
	set pstart  [find_geometry_item_data $start]
	set pend    [find_geometry_item_data $end]

	set cx [lindex $pcentre 0]
	set cy [lindex $pcentre 1]
	set sx [lindex $pstart 0]
	set sy [lindex $pstart 1]
	set ex [lindex $pend 0]
	set ey [lindex $pend 1]

	set cx2 [expr $cx+100]

	# Work out the start and end angles 
	set start_angle [angle_between_lines "$cx $cy $cx2 $cy" "$cx $cy $sx $sy"] 
	set end_angle   [angle_between_lines "$cx $cy $cx2 $cy" "$cx $cy $ex $ey"] 

	set gr [expr sqrt(($cx-$sx)*($cx-$sx)+($cy-$sy)*($cy-$sy))]
	geometry_store arc $gname "$cx $cy $gr $start_angle $end_angle"
	puts "arc: $gname $cx $cy $gr"
    }
    return ""
}

proc proccircleatwithradius {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname gx gy gr ] } {
	# We store circles as arcs
	geometry_store arc $gname "$gx $gy $gr 0.0 360.0"
	puts "circle: $gname $gx $gy $gr"
    }
    return ""
}

# Circle tangennt to 2 lines and a given radius

proc proccircletangent2linesradius {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname l1 l2 radius modifiers] } {
	# Get the line details
	set line1 [find_geometry_item_data $l1]
	set line2 [find_geometry_item_data $l2]
	puts "l1=$line1  l2=$line2 radius =$radius modifier=$modifiers"

	puts "Circle tangent to 2 lines given radius"

	# Work out angle between lines
	set angle [angle_between_lines $line1 $line2]
	puts "Angle = $angle"

	# We have to pick the correct angle here, there's four solutions to this problem, we pick the 
	# one selected by the modifier, or a default
	# calculate all solutions
	set angle1 $angle
	set angle2 [expr 180-$angle]

	# We can now work out how far from the intersection of the lines the circle centre is, along the bisecting line
	# There's two angles, this will lead us to four solutions
	set d1 [expr $radius/sin(($angle1/2.0)/180*$::PI)]
	set d2 [expr $radius/sin(($angle2/2.0)/180*$::PI)]

	puts "d1=$d1, d2=$d2"

	# Find bisecting lines
	set bls [lines_bisecting $line1 $line2]

	# Find intersection point of lines
	set int_pt [line_intersection $line1 $line2]

	# We can now find two intersections of circles for each angle
	set bl1 [lindex $bls 0]
	set bl2 [lindex $bls 1]

	puts "Bisect lines =$bls"
	geometry_store line _cons_bisect1 $bl1
	geometry_store line _cons_bisect2 $bl2

	# Two circles centred on the intersection point of the lines and with radius equal to the distance
	# of the solution circles centre from the intersection point
	set c1 [list [lindex $int_pt 0] [lindex $int_pt 1] $d1]
	set c2 [list [lindex $int_pt 0] [lindex $int_pt 1] $d2]

	geometry_store circle _cons_c1 $c1
	geometry_store circle _cons_c2 $c2

	# Get intersection points
	set intpts ""
	foreach pt [intersection_line_circle $bl1 $c1] {
	    lappend intpts $pt
	}
	puts "int points = $intpts"
	foreach pt [intersection_line_circle $bl2 $c2] {
	    lappend intpts $pt
	}

	puts "int points = $intpts"
	geometry_store_modifier_qualified_points $intpts $modifiers $gname $radius {list $x $y $parameter} {geometry_store circle $gname$suffix $object}
    }
    return ""
}


#----------------------------------------------------------------------------------------------------
#
# Stores in the geometry database only those points that match the modifier list
# Point names have a suffix added which is an index if there's more than one point, otherwise 
# just the given name is used
#

proc geometry_store_modifier_qualified_points {point_list modifiers gname parameter createscript store_script} {
    
    # Now use modifiers to work out which circles to create
    # We can create more than one, in which case we will add a suffix that is the modifier name
    set modifierlist {smallx smally largex largey allcircles}
    
    # Set modifier flags
    foreach modifier $modifierlist {
	set $modifier 0
	puts "Modifier $modifier := 0"
    }
    
    foreach modifier $modifierlist { 
	if { [string first $modifier $modifiers] != -1 } {
	    set $modifier 1
	    puts "Modifier $modifier := 1"
	}
    }
    
    # Scan through calculating largest and smallest X and Y
    set index 0
    set largestx -1e6
    set largesty -1e6
    set smallestx 1e6
    set smallesty 1e6
    
    foreach point $point_list {
	set x [lindex $point 0]
	set y [lindex $point 1]
	
	if { $x > $largestx } {
	    set largestx $x
	}
	
	if { $x < $smallestx } {
	    set smallestx $x
	}
	
	if { $y > $largesty } {
	    set largesty $y
	}

	if { $y < $smallesty } {
	    set smallesty $y
	}
    }

    # Scan through to find out how many points will be created
    # We do this so we can rwork out whether to add a suffix or not

    set pointcount 0

    foreach point $point_list {
	set x [lindex $point 0]
	set y [lindex $point 1]
	set object [eval $createscript]

	set createflag 1

	if { $smallx } {
	    if { ![approx_equal $x $smallestx] } {
		set createflag 0
	    }
	}

	if { $largex } {
	    if { ![approx_equal $x $largestx] } {
		set createflag 0
	    }
	}

	if { $smally } {
	    if { ![approx_equal $y $smallesty] } {
		set createflag 0
	    }
	}

	if { $largey } {
	    if { ![approx_equal $y $largesty] } {
		set createflag 0
	    }
	}

	if { $allcircles } {
	    set createflag 1
	}

	if { $createflag } {
	    incr pointcount 1
	}
    }

    # Now create the points that match the modifiers
    foreach point $point_list {
	set x [lindex $point 0]
	set y [lindex $point 1]
	set object [eval $createscript]

	set createflag 1
	set suffix ""

	if { $smallx } {
	    if { ![approx_equal $x $smallestx] } {
		set createflag 0
	    }

	}

	if { $largex } {
	    if { ![approx_equal $x $largestx] } {
		set createflag 0
	    }
	}

	if { $smally } {
	    if { ![approx_equal $y $smallesty] } {
		set createflag 0
	    }
	}

	if { $largey } {
	    if { ![approx_equal $y $largesty] } {
		set createflag 0
	    }
	}

	if { $allcircles } {
	    set createflag 1
	}

	if { $createflag } {
	    if { $pointcount > 1 } {
		set suffix $index
	    } else {
		set suffix ""
	    }

	    eval $store_script

	    incr index 1
	}
    }
}


# Set up a limit line which will stop a GO command
set ::LIMITLINEINDEX 0

proc proclimitline {line} {
    set pat [findpat]
    set output ""
    if { [regexp -- $pat $line all modifier line1] } {
	# Store the limit line as a global by name. Also store the modifier by name
	set ::LIMIT_LINE $line1
	set ::LIMIT_LINE_MODIFIER $modifier
	append output "(Limit line now $modifier $line1)\n"
    }
    return $output
}

# Line parallel to another line at a given distance.
# Which side is dfined as left/right

proc proclineparalleltoatdistance {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname ln distance side ] } {
	set ln1 [find_geometry_item_data $ln]
	set x1 [lindex $ln1 0]
	set y1 [lindex $ln1 1]
	set x2 [lindex $ln1 2]
	set y2 [lindex $ln1 3]

	set pl [get_line_parallel_to $x1 $y1 $x2 $y2 $distance $side]

	geometry_store line $gname $pl
    }

    return ""
}

# Line through a point at an angle
proc procline1pointatangle {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname point angle ] } {
	# Get point
	set p1 [find_geometry_item_data $point]
	set p1x [lindex $p1 0]
	set p1y [lindex $p1 1]

	# Lines are defined by any two points on the line. We have one point, we just need to 
	# create another one on the line
	set p2x [expr $p1x+$::ARBITRARY_LINE_LENGTH*cos($angle/180.0*$::PI)]
	set p2y [expr $p1y+$::ARBITRARY_LINE_LENGTH*sin($angle/180.0*$::PI)]
	geometry_store line $gname "$p1x $p1y $p2x $p2y"
    }
    return ""
}


# Line between two points
proc procline2points {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname point1 point2 ] } {

	# Work out line between points
	set p1 [find_geometry_item_data $point1]
	set p2 [find_geometry_item_data $point2]

	if { ([string compare $p1 none] == 0) } {
	    doerror "Point $point1 unknown"
	    return
	}
	if { ([string compare $p2 none] == 0) } {
	    doerror "Point $point2 unknown"
	    return
	}

	set gx1 [lindex $p1 0]
	set gy1 [lindex $p1 1]
	set gx2 [lindex $p2 0]
	set gy2 [lindex $p2 1]

	# Work out the line between these two points
	geometry_store line $gname "$gx1 $gy1 $gx2 $gy2"
	puts "line: $gname $gx1 $gy1 $gx2 $gy2"
    }
    return ""
}

#----------------------------------------------------------------------------------------------------

set ::OUTPUT ""

proc procfeed {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all speed ] } {
	append output "F $speed\n"
    }
    puts "Feed=>$output"
    return $output
}

proc proctooldia {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all dia ] } {
	append output "(Tool diameter: $dia)\n"

	# We have global tool diameter
	set ::TOOLDIA $dia
    }
    return $output
}

set ::IN_TOOLPATH 0

proc proctoolpath {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all gname] } {
	set ::IN_TOOLPATH 1
	set ::TOOLPATH_NAME $gname
	set ::TOOLPATH_TEXT($::TOOLPATH_NAME) "starttoolpath $::TOOLPATH_NAME\n"
	set ::TOOLPATH_TEXT($::TOOLPATH_NAME) "(Toolpath $::TOOLPATH_NAME)\n"
	lappend ::TOOLPATHS $gname
    }
    return ""
}

#----------------------------------------------------------------------------------------------------

# This is never used in a toolpath, it is used to put the prefix output when a toolpath is run

proc procstarttoolpath {line} {
    set pat [findpat]

    if { [regexp -- $pat $line all gname] } {
	if {0} {
	    set now [clock format [clock seconds]]
	    append output "(Generated with simpleapt.tcl)\n"
	    append output "($now)\n"
	    append output "(Created from file: $::FILENAME)\n"
	    append output "G21 (Unit in mm)\n"
	    append output "G90 (Absolute distance mode)\n"
	    append output "G64 P0.01 (Exact Path 0.001 tol.)\n"
	    append output "G17\n"
	    append output "G40 (Cancel diameter comp.)\n"
	    append output "G49 (Cancel length comp.)\n"
	    append output "T1M6 (Tool change to T1)\n"
	    append output "M8 (Coolant flood on)\n"
	    append output "S5000M03 (Spindle 5000rpm cw)\n"
	    append output "(Toolpath: $gname)\n"
	}

    }

    return $output
}

# Outputs the prefix for the file

proc file_prefix {} {
    set output ""

    set now [clock format [clock seconds]]
    append output "(Generated with simpleapt.tcl)\n"
    append output "($now)\n"
    append output "(Created from file: $::FILENAME)\n"
    append output "G21 (Unit in mm)\n"
    append output "G90 (Absolute distance mode)\n"
    append output "G64 P0.01 (Exact Path 0.001 tol.)\n"
    append output "G17\n"
    append output "G40 (Cancel diameter comp.)\n"
    append output "G49 (Cancel length comp.)\n"
    append output "T1M6 (Tool change to T1)\n"
    append output "M8 (Coolant flood on)\n"
    append output "S5000M03 (Spindle 5000rpm cw)\n"
    append output "\n"

    
    return $output
}

proc file_suffix {} {
    set output ""
    append output "M9 (Coolant off)\n"
    append output "M5 (Spindle off)\n"
    append output "M2 (Prgram end)\n"
    return $output
}

#----------------------------------------------------------------------------------------------------
#
# Cuts a single toolpath
#
#

proc proccutpath {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all gname] } {

	# We aren't in a toolpath as we are cutting one
	set ::IN_TOOLPATH 0	
	set output [execute_text $::TOOLPATH_TEXT($gname)]
    }
    puts "cutpath=>'$output'"

    return $output
}

#
# Cuts a  toolpath multiple times with a sequence of cut depths
#

proc proccutpathwithz {line} {
    set pat [findpat]

    set output ""
    if { [regexp -- $pat $line all gname zstart zend zstep] } {

	# We aren't in a toolpath as we are cutting one
	set ::IN_TOOLPATH 0	
	puts "zstart=$zstart zend=$zend zstep=$zstep"

	foreach z [ab_to_list $zstart $zend $zstep] {
	    # Set Z
	    append output "\nG1 Z $z\n"

	    # Cut toolpath
	    append output [execute_text $::TOOLPATH_TEXT($gname)]
	}
    }

    return $output
}

#----------------------------------------------------------------------------------------------------

proc procendpath {line} {
    set ::IN_TOOLPATH 0
    puts "End of toolpath storage"
    return ""
}

proc endtoolpath {line} {
    set ::IN_TOOLPATH 0
    append output "M9 (Coolant off)\n"
    append output "M5 (Spindle off)\n"
    append output "M2 (Prgram end)\n"
    return $output
}

# Start
# We set up the start position as a point 
# Tool dia offset is done in the GO command

proc procstartat {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all pointa] } {
	#  get the details of the two points 
	set pa [find_geometry_item_data $pointa]
	set pax [lindex $pa 0]
	set pay [lindex $pa 1]

	# Move to this position
	append output "G1 X $pax Y $pay"

	set_current_position $pax $pay 0
	set ::AT_START 1
    }
    return $output
}

#----------------------------------------------------------------------------------------------------
#
# Go to specific Z
#

proc procgoznum {line} {
    set pat [findpat]
    set output ""

    if { [regexp -- $pat $line all zval] } {
	append output "G1 Z $zval\n"
    }

    return $output
}

#----------------------------------------------------------------------------------------------------

# Go to
# We generate gcode for a move between two points
# The tool diameter has to be accounted for and we use the left or right for that
# The toolpath may have to go past the end point by the tool diameter, this is set by the past keyword

set ::INTPOINTINDEX 0

proc procgo {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all rightleft toalong item ] } {
	#  Get the end point
	switch -exact $toalong {
	    to {
		set pb [find_geometry_item_data $item]
	    }
	    along {
		set lb [find_geometry_item_data $item]
		set pb [list [lindex $lb 2] [lindex $lb 3]]
	    }
	    direction {
		set lb [find_geometry_item_data $item]
		# Treat line as a vector and calculate second point using direction of vector
		set vx [expr [lindex $lb 0] - [lindex $lb 2]]
		set vy [expr [lindex $lb 1] - [lindex $lb 3]]
		set pbx [expr $::CURX + $vx]
		set pby [expr $::CURY + $vy]
		set pb [list $pbx $pby]
	    }
	}

	if { ([string compare $pb none] == 0) } {
	    doerror "Point $pointb unknown"
	}

	puts ">>>GO<<<"
	set pa [list $::CURX $::CURY $::CURZ]
	puts $pb

	# Find line through points
	set ax [lindex $pa 0]
	set ay [lindex $pa 1]
	set bx [lindex $pb 0]
	set by [lindex $pb 1]

	# Work out distance the cutter must travel from the part
	set d [expr $::TOOLDIA /2.0]

	set parallel [get_line_parallel_to $ax $ay $bx $by $d $rightleft]

	set rax [lindex $parallel 0]
	set ray [lindex $parallel 1]
	set rbx [lindex $parallel 2]
	set rby [lindex $parallel 3]

	# If there is a previous line then we have to start at the intersection of that line and this one
	if { 0 } {
	    if { [llength $::PREVIOUS_LINE] != 0 } {
		set x1 [lindex $::PREVIOUS_LINE 0]
		set y1 [lindex $::PREVIOUS_LINE 1]
		set x2 [lindex $::PREVIOUS_LINE 2]
		set y2 [lindex $::PREVIOUS_LINE 3]

		set intersection [line_intersection_points $rax $ray $rbx $rby $x1 $y1 $x2 $y2] 

		set ix [lindex $intersection 0]
		set iy [lindex $intersection 1]

		append output "(Move to intersection of previous line and this line before we start)\n"
		append output "G1 X $ix Y $iy\n"
	    }
	}
	# If there's a limit line then we have to stop at the intersection of that line and this one, taking modifiers of
	# before, on and after into account
	if { [string compare $::LIMIT_LINE  none] != 0 } {
	    # There is a limit line, get it's co-ords
	    set ll [find_geometry_item_data $::LIMIT_LINE]
	    set llx1 [lindex $ll 0]
	    set lly1 [lindex $ll 1]
	    set llx2 [lindex $ll 2]
	    set lly2 [lindex $ll 3]

	    puts "Limit line is $llx1 $lly1 $llx2 $lly2"

	    # Get three lines, all parallel to the limit line. One for before, one for on and one for after
	    set on_line     [list $llx1 $lly1 $llx2 $lly2]
	    set after_line  [get_line_parallel_to $llx1 $lly1 $llx2 $lly2 $d right]
	    set before_line [get_line_parallel_to $llx1 $lly1 $llx2 $lly2 $d left]
	    
	    # Store these in geometry for debug
	    geometry_store line LIMLINO$::LIMITLINEINDEX $on_line
	    geometry_store line LIMLINB$::LIMITLINEINDEX $before_line
	    geometry_store line LIMLINA$::LIMITLINEINDEX $after_line
	    incr ::LIMITLINEINDEX 1

	    # Get intersection of cut line with all three of these lines
	    set x3 [lindex $on_line 0]
	    set y3 [lindex $on_line 1]
	    set x4 [lindex $on_line 2]
	    set y4 [lindex $on_line 3]
	    set intersection_on [line_intersection_points $rax $ray $rbx $rby $x3 $y3 $x4 $y4]

	    set x3 [lindex $after_line 0]
	    set y3 [lindex $after_line 1]
	    set x4 [lindex $after_line 2]
	    set y4 [lindex $after_line 3]
	    set intersection_after [line_intersection_points $rax $ray $rbx $rby $x3 $y3 $x4 $y4]

	    set x3 [lindex $before_line 0]
	    set y3 [lindex $before_line 1]
	    set x4 [lindex $before_line 2]
	    set y4 [lindex $before_line 3]
	    set intersection_before [line_intersection_points $rax $ray $rbx $rby $x3 $y3 $x4 $y4]

	    # Add intersection points for debug
	    geometry_store point INTPTO_$item\_$::INTPOINTINDEX $intersection_on
	    geometry_store point INTPTA_$item\_$::INTPOINTINDEX $intersection_after
	    geometry_store point INTPTB_$item\_$::INTPOINTINDEX $intersection_before
	    incr ::INTPOINTINDEX 1

	    # Now choose our before, after and on points based on how far from the start of the cut line they are
	    set dist_on     [distance_between $rax $ray [lindex $intersection_on 0]     [lindex $intersection_on 1]]
	    set dist_after  [distance_between $rax $ray [lindex $intersection_after 0]  [lindex $intersection_after 1]]
	    set dist_before [distance_between $rax $ray [lindex $intersection_before 0] [lindex $intersection_before 1]]
	    
	    # We know on must be on, so handle that
	    switch $::LIMIT_LINE_MODIFIER {
		on {
		    set rbx [lindex $intersection_on 0]
		    set rby [lindex $intersection_on 1]
		}
		after {
		    if { $dist_after > $dist_before } {
			set rbx [lindex $intersection_after 0]
			set rby [lindex $intersection_after 1]
		    } else {
			set rbx [lindex $intersection_before 0]
			set rby [lindex $intersection_before 1]
		    }
		}
		before {
		    if { $dist_before > $dist_after } {
			set rbx [lindex $intersection_after 0]
			set rby [lindex $intersection_after 1]
		    } else {
			set rbx [lindex $intersection_before 0]
			set rby [lindex $intersection_before 1]
		    }
		}
	    }
	}

	# If we are at the start position then we need to move to the cutter diameter offset corrected 
	# position

	if { $::AT_START } {
	    append output "(Move to tool dia corrected point at end of line)\n"
	    #append output "G1 X $rax  Y $ray\n"
	}

	if { 0 } {
	    if { [info exists ix] } {
		append output "G1 X $ix  Y $iy\n"
		append output "G1 X $ax   Y $ay\n"
		append output "G1 X $ix  Y $iy\n"
	    }
	}

	# Write output 
	#	append output "G1 X $rax  Y $ray\n"
	append output "G1 X $rbx  Y $rby\n"

	set_current_position $bx $by 0

	set ::PREVIOUS_LINE [list $rax $ray $rbx $rby]

	puts $::logf "ax  : $ax"
	puts $::logf "ay  : $ay"
	puts $::logf "bx  : $bx"
	puts $::logf "by  : $by"
	puts $::logf "rax : $rax"
	puts $::logf "ray : $ray"
	puts $::logf "rbx : $rbx"
	puts $::logf "rby : $rby"
    }
    return $output
}

#----------------------------------------------------------------------------------------------------
#
# Go along
#
# We generate code to move along a line to a limit line
#

proc procgoalong {line} {
    set pat [findpat]
    
    if { [regexp -- $pat $line all rightleft ln ] } {

	set aln [find_geometry_item_data $ln]

	# We need to find the start and end coords of the movement
	# The start is where we are now, the end will be the intersection of the line (modified left or right or on)
	# and the limit surface if there is one. If there isn't then it's the end of the line

    }
    return ""
}


#----------------------------------------------------------------------------------------------------
proc execute_text {text} {

    puts "Executing '$text'"

    foreach line [split $text "\n"] {
	# Make case insensitive
	set line [string tolower $line]

	puts "::$line"

	# Substitute values
	regsub -all {\$([a-z0-9_]+)} $line "\$::VALUE(\\1)" line
	set line [subst $line]
	puts ">>$line"

	foreach pattern $::PAT {
	    set fmt [lindex $pattern 0]
	    set procname [lindex $pattern 1]
	    
	    if { [string compare $line endpath] == 0 } {
		puts "Ending toolpath capture"
		set ::IN_TOOLPATH 0
		break
	    }

	    if { [regexp -- $fmt $line all] } {
		puts $::logf $procname
		if { $::IN_TOOLPATH } {
		    puts "Append (IN_TOOLPATH=$::IN_TOOLPATH)"
		    append ::TOOLPATH_TEXT($::TOOLPATH_NAME) "$all\n"
		} else {
		    puts "Execute '$procname' (IN_TOOLPATH=$::IN_TOOLPATH)"
		    append output [$procname $all]
		}
		break
	    }
	}
    }
    return $output
}


set filename [lindex $argv 0]
set ::FILENAME $filename

set f [open $filename]
set ::FILETEXT [read $f]
close $f

set ::OUTPUT [file_prefix]
append ::OUTPUT [execute_text $::FILETEXT]
append ::OUTPUT [file_suffix]

print_geometry_database
print_toolpaths
print_value

set f [open output.nc w]
puts $f $::OUTPUT
close $f


close $::logf


################################################################################

proc DrawGeometry {} {
    
    set w .geometry
    
    CreateCanvasWindow $w "Geometry"
    ResetScale X
    ResetScale Y
    
    # Scale drawing
    DrawGeometryInCanvas $w 0

    # Draw drawing
    DrawGeometryInCanvas $w 1

}

proc Range {xory val} {
    set min [set ::MIN$xory]
    set max [set ::MAX$xory]

    if { $val > $max } {
	set ::MAX$xory $val
    }

    if { $val < $min} {
	set ::MIN$xory $val
    }
}

proc ResetScale {xory} {
    set ::MIN$xory 1e6
    set ::MAX$xory -1e6
}

proc SetScale {xory} {
    set min [set ::MIN$xory]
    set max [set ::MAX$xory]

    set ::RANGE$xory [expr $max-$min]
    set ::OFFSET$xory [expr $min]
}

proc EqualizeScales {xorylist} {

    set maxrange 0
    foreach xory [split $xorylist " "] {
	set min [set ::MIN$xory]
	set max [set ::MAX$xory]
	puts "Scale $xory => $min .. $max"
	if { [set ::RANGE$xory] > $maxrange } {
	    set maxrange [set ::RANGE$xory]
	    set max_xory $xory
	}
    }

    # Set all ranges the same
    foreach xory [split $xorylist " "] {
	set ::RANGE$xory $maxrange
	set ::MIN$xory [set ::MIN$xory]
    }

}


proc Scale {xory val} {
    set size   [set ::SIZE$xory]
    set range  [set ::RANGE$xory]
    set offset [set ::OFFSET$xory]
    set min    [set ::MIN$xory]

    switch $xory {
	Y {
	    set result [expr $size - ($size * ($val-$min) / $range) + $offset]
	}
	default {
	    set result [expr          $size * ($val-$min) / $range  + $offset]
	}

    }
}

proc DrawGeometryInCanvas {w draw_n_scale} {
    
    if { !$draw_n_scale } {
	# Auto scale
	
	foreach item $::G_NAMES {
	    set data $::G_DATA($item)
	    set type $::G_TYPE($item)
	    
	    switch $type {
		line {
		    Range X [lindex $data 0]
		    Range Y [lindex $data 1]
		    Range X [lindex $data 2]
		    Range Y [lindex $data 3]
		}
		
		point {
		    Range X [lindex $data 0]
		    Range Y [lindex $data 1]
		}
		circle {
		    Range X [expr [lindex $data 0] + [lindex $data 2]]
		    Range X [expr [lindex $data 0] - [lindex $data 2]]
		    Range Y [expr [lindex $data 1] + [lindex $data 2]]
		    Range Y [expr [lindex $data 1] - [lindex $data 2]]
		}

	    }
	}


	# Use ranges to work out scale
	SetScale X
	SetScale Y
	EqualizeScales "X Y"
	
	ExpandScrollRegion $w.frame.c $::MINX $::MINY $::MAXX $::MAXY
    }
    
    if { $draw_n_scale } {
	# Draw it
	foreach item $::G_NAMES {
	    set data $::G_DATA($item)
	    set type $::G_TYPE($item)

	    set nodraw 0

	    # Colour depends on the item name
	    switch -regexp $item {
		^INTPT.*$ {
		    # Construction line
		    set colour grey
		    set nodraw 1
		}
		^LIMLIN.*$ {
		    # Construction line
		    set colour grey
		    set nodraw 1
		}
		^_cons_.*$ {
		    # Construction line
		    set colour darkgrey
		}
		
		default {
		    set colour black
		}
		
	    }
	    
	    if { !$nodraw } {	    
		switch $type {
		    line {
			set x1 [Scale X [lindex $data 0]]
			set y1 [Scale Y [lindex $data 1]]
			set x2 [Scale X [lindex $data 2]]
			set y2 [Scale Y [lindex $data 3]]
			
			puts "line $data"
			$w.frame.c create line $x1 $y1 $x2 $y2 -fill $colour
			$w.frame.c create text [expr ($x1+$x2)/2] [expr ($y1+$y2)/2] -text $item -fill $colour
		    }
		    
		    point {
			set x1 [Scale X [lindex $data 0]]
			set y1 [Scale Y [lindex $data 1]]
			
			$w.frame.c create oval [expr $x1-$::DOTX]  [expr $y1-$::DOTY]  [expr $x1+$::DOTX]  [expr $y1+$::DOTY]  -outline $colour
			$w.frame.c create text $x1 $y1 -anchor nw -text $item -fill $colour
		    }

		    circle {
			# We assume the x and y scale are the same as we can only draw a circle as a circle
			set x [lindex $data 0]
			set y [lindex $data 1]
			set r [lindex $data 2]
			
			$w.frame.c create oval [Scale X [expr $x-$r]]  [Scale Y [expr $y-$r]]  [Scale X [expr $x+$r]]  [Scale Y [expr $y+$r]]  -outline $colour
			$w.frame.c create text [Scale X [expr $x-$r]] [Scale Y $y] -anchor nw -text $item -fill $colour
		    }
		}
	    }
	}
    }
}

proc DrawToolpath {} {

    set w .toolpath

    CreateCanvasWindow $w "output.nc"

    ResetScale X
    ResetScale Y

    # Scale drawing
    DrawToolpathInCanvas $w 0

    # Draw drawing
    DrawToolpathInCanvas $w 1

}

proc DrawToolpathInCanvas {w draw_n_scale} {

    if { !$draw_n_scale } {

	# Auto scale
	set f [open output.nc]
	set nctxt [read $f]
	close $f
	
	set lastx 0
	set lasty 0
	set lastvalid 0
	
	foreach line [split $nctxt "\n"] {
	    switch -regexp $line {
		^G0 {
		    if { [regexp -- {G0[ ]*X[ ]*([0-9.e-]+)[ ]*Y[ ]*([0-9.e-]+)} $line all xval yval] } {
			Range X $xval
			Range Y $yval
		    }
		}
		
		^G1 {
		    if { [regexp -- {G1[ ]*X[ ]*([0-9.e-]+)[ ]*Y[ ]*([0-9.e-]+)} $line all xval yval] } {
			
			Range X $xval
			Range Y $yval
		    }
		}
	    }
	}
    }

    # Now draw the toolpath
    if { $draw_n_scale } {
	set col $::TOOLPATH_COLOUR

	set f [open output.nc]
	set nctxt [read $f]
	close $f
	
	set lastx 0
	set lasty 0
	set lastvalid 0
	
	foreach line [split $nctxt "\n"] {
	    switch -regexp $line {
		^G0 {
		    if { [regexp -- {G0[ ]*X[ ]*([0-9.e-]+)[ ]*Y[ ]*([0-9.e-]+)} $line all xval yval] } {
			
			set x1 [Scale X $xval]
			set y1 [Scale Y $yval]
			
			if { $lastvalid } {
			    $w.frame.c create line $lastx $lasty $x1 $y1 -arrow last -fill $col
			} else {
			    $w.frame.c create oval [expr $x1-$::DOTX] [expr $y1-$::DOTY] [expr $x1+$::DOTX] [expr $y1+$::DOTY] -outline $col
			}
			set lastx $x1
			set lasty $y1		    
			set lastvalid 1		    
		    }
		}
		
		^G1 {
		    if { [regexp -- {G1[ ]*X[ ]*([0-9.e-]+)[ ]*Y[ ]*([0-9.e-]+)} $line all xval yval] } {
			
			set x1 [Scale X $xval]
			set y1 [Scale Y $yval]
			
			if { $lastvalid } {
			    $w.frame.c create line $lastx $lasty $x1 $y1 -arrow last -fill $col
			} else {
			    $w.frame.c create oval [expr $x1-$::DOTX] [expr $y1-$::DOTY] [expr $x1+$::DOTX] [expr $y1+$::DOTY] -outline $col
			}
			set lastx $x1
			set lasty $y1
			set lastvalid 1		    
		    }
		}
	    }
	}
    }
}

proc DrawGeometryAndToolpath {} {

    set w .toolpath

    CreateCanvasWindow $w "Toolpath And Geometry"

    # Reset Scale
    ResetScale X
    ResetScale Y

    # Auto scale drawings
    DrawToolpathInCanvas $w 0
    DrawGeometryInCanvas $w 0

    # Draw drawings
    DrawToolpathInCanvas $w 1
    DrawGeometryInCanvas $w 1
}

####################################################################################################
#Main menu

set w ""

menu $w.menu -tearoff 0

$w.menu add cascade -label "File"         -menu $w.menu.file -underline 0
$w.menu add cascade -label "Geometry"     -menu $w.menu.geometry -underline 0
$w.menu add cascade -label "Toolpaths"    -menu $w.menu.toolpaths -underline 0

menu $w.menu.file -tearoff 0
menu $w.menu.geometry -tearoff 0
menu $w.menu.toolpaths -tearoff 0

set m $w.menu.file
$m add command -label "Preferences" -command {Setup }
$m add command -label "Exit" -command exit

set m $w.menu.geometry
$m add command -label "Draw Geometry" -command {DrawGeometry}
$m add command -label "Draw Geometry And Toolpath" -command {DrawGeometryAndToolpath}

set m $w.menu.toolpaths
$m add command -label "draw Toolpath" -command {DrawToolpath}

. configure -menu $w.menu

wm title . "GCode Simple APT"

DrawGeometry