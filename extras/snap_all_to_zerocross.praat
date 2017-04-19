# move_all_bound_zerocross_from_shell.psc
# Moves all boundaries in _IntervalTiers_ to the 
# nearest zero crossing
#
# Select a TextGrid + a Sound | Praat | Open and run this script
#
# 09.11.2005 John T�ndering (move_all_bound_zerocross.psc)
# 21.06.2006 JT: Run from shell
# 26.12.2011 JK: modified to open all TextGrid/Sounds in a directory and snap to zero 
# 05.03.2014 JK: modified to handle point tier
# 17.03.2017 JK: modified to snap all boundaries on all tiers indiscriminately

form Enter directory and search string
    sentence Directory /Users/jkirby/Desktop/cbt-test/
    sentence Extension .wav
    integer AudioChannel 1
endform

########################
## for interval tiers
########################
procedure interval_snap (this_tier)

    number_of_intervals = Get number of intervals... this_tier 

    for j to number_of_intervals
        end_grid   = Get end point... this_tier j
        select sound
        zero_cros  = Get nearest zero crossing... audioChannel end_grid
        select textgrid
        if j < number_of_intervals
            if end_grid <> zero_cros
                if zero_cros > end_grid
                    lab$ = Get label of interval... this_tier j+1
                    Set interval text... this_tier j+1 
                    Insert boundary... this_tier zero_cros
                    Remove boundary at time... this_tier end_grid
                    Set interval text... this_tier j+1 'lab$'
                else
                    Insert boundary... this_tier zero_cros
                    Remove boundary at time... this_tier end_grid
               endif
           endif
        endif
    endfor	
endproc

########################
## for point tiers
########################
procedure point_snap (this_tier)

    number_of_points = Get number of points... this_tier

    for j to number_of_points
	  point_time = Get time of point... this_tier j
	  point_label$ = Get label of point... this_tier j
        select sound
        zero_cros  = Get nearest zero crossing... audioChannel point_time
        select textgrid
        ## check to see if point already at zero crossin
        if point_time <> zero_cros
            Remove point... this_tier j
            Insert point... this_tier zero_cros 'point_label$'
       endif
    endfor	
endproc

########################
## main script
########################

clearinfo

Create Strings as file list... list 'directory$'*'extension$'
number_of_files = Get number of strings
for x from 1 to number_of_files
    select Strings list
    current_file$ = Get string... x
    Read from file... 'directory$''current_file$'
    object_name$ = selected$("Sound")
    sound = selected ("Sound")
    Read from file... 'directory$''object_name$'.TextGrid
    textgrid = selected ("TextGrid")
    select textgrid

    ## get number of tiers
    number_of_tiers = Get number of tiers

    ## loop through all tiers
    for i from 1 to number_of_tiers
        is_interval = Is interval tier... i
        if is_interval
            @interval_snap: i
        else
            @point_snap: i
        endif
    endfor

    minus Sound 'object_name$'
    Write to text file... 'directory$''object_name$'.TextGrid
    select all	    
    minus Strings list
    Remove
endfor

select Strings list
Remove
print All files processed -- that was fantastic!

