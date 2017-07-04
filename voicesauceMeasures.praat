### spectralMagniture.praat
## version 0.1
## James  Kirby <j.kirby@ed.ac.uk>
## based on code by Timothy Mills, Chad Vicenik, Patrick Callier and the VoiceSauce codebase 
##
## It is designed to work as part of the "praatsauce" script suite,
## which can be obtained from the author:
##
##   James Kirby <j.kirby@ed.ac.uk>
##
## This script is released under the GNU General Public License version 3.0 
## The included file "gpl-3.0.txt" or the URL "http://www.gnu.org/licenses/gpl.html" 
## contains the full text of the license.


# This script is designed to measure spectral tilt following the technique 
# described by Iseli et al. (2007):
#
# Iseli, M., Y.-L Shue, and A. Alwan.  2007.  Age, sex, and vowel 
#   dependencies of acoustic measures related to the voice source.
#	Journal of the Acoustical Society of America 121(4): 2283-2295.
#
# This method aims to correct the magnitudes of the spectral harmonics
# by compensating for the influence of formant frequencies on the 
# spectral magnitude estimation. From the article (p.2285):
#
# "The purpose of this correction formula is to “undo” the effects of
# the formants on the magnitudes of the source spectrum. This is done 
# by subtracting the amount by which the formants boost the spectral 
# magnitudes. For example, the corrected magnitude of the first spectral
# harmonic located at frequency \omega_0 [H*(\omega_0)], where 
# \omega_0 = 2\pi F_0 and F_0 is the fundamental frequency, is given by
#
#	   									   (1 - 2r_i \cos(\omega_i) + r^2_i)^2
# H(\omega_0) - \sum_{i=1}^{N} 10\log_10 ( ------------------------------------- )
#	   							 	    (1 - 2r_i \cos(\omega_0 + \omega_i) + r^2_i) * 
#	   								    (1 - 2r_i \cos(\omega_0 - \omega_i) + r^2_i)
#
# with r_i = e^{-\pi B_i/F_s} and \omega_i = 2\pi F_i/F_s where F_i and
# B_i are the frequencies and bandwidths of the ith formant, F_s is the 
# sampling frequency, and N is the number of formants to be corrected for. 
# H(\omega_o) is the magnitude of the first harmonic from the speech 
# spectrum and H*(\omega_0) represents the corrected magnitude and should
# coincide with the magnitude of the source spectrum at \omega_0. Note that 
# all magnitudes are in decibels." (2285-6)
# 
# Note that there is an error in the above (from the 2007 paper): the
# frequency of ALL harmonics needs to be corrected for the sampling 
# frequency F_s. This is correctly noted in Iseli & Alwan (2004), Sec. 3.
#
# Formant bandwidths are calculated using the formula in Mannell (1998):
#
# B_i = (80 + 120F_i/5000)
#
# "For H1* and H2*, the correction was for the ﬁrst and second formant 
# (F1 and F2) inﬂuence with N=2 in Eq. (A5). For A3*, the first three 
# formants were corrected for (N=3) and there was no normalization to 
# a neutral vowel; recall that our correction accounts for formant 
# frequencies and their bandwidths." (2286-7)
#
# The authors note that the measures are dependent on vowel quality (F1) 
# and vowel type, but this is not expressly corrected for here. 
#
# See the paper (or the algorithm coded below) for details.  
#
#
# This script is released under the GNU General Public License version 3.0 
# The included file "gpl-3.0.txt" or the URL "http://www.gnu.org/licenses/gpl.html" 
# contains the full text of the license.

form Parameters for spectral tilt measure following Iseli et al.
 comment TextGrid interval to measure.  If numeric, check the box.
 natural tier 1
 integer interval_number 0
 text interval_label v
 comment Window parameters
 real windowPosition 0.5
 positive windowLength 0.025
 comment Output
 boolean outputToMatrix 1
 boolean saveAsEPS 0
 sentence inputdir /home/username/data/
 comment Manually check token?
 boolean manualCheck 1
 comment Analysis parameters
 positive maxDisplayHz 4000
 positive measure 2
 positive timepoints 3
 positive timestep 1
 positive f0min 50
 positive f0max 500
endform

###
### First, check that proper objects are present and selected.
###
numSelectedSound = numberOfSelected("Sound")
numSelectedTextGrid = numberOfSelected("TextGrid")
numSelectedFormant = numberOfSelected("Formant")
numSelectedPitch = numberOfSelected("Pitch")
if (numSelectedSound<>1 or numSelectedTextGrid<>1 or numSelectedFormant<>1 or numSelectedPitch<>1)
 exit Select one Sound, one TextGrid, one Pitch, and one Formant object.
endif
name$ = selected$("Sound")
soundID_orig = selected("Sound")
textGridID = selected("TextGrid")
pitchID = selected("Pitch")
formantID = selected("Formant")
### (end object check)

###
### Second, establish time domain.
###
select textGridID
if 'interval_number' > 0
 intervalOfInterest = interval_number
else
 numIntervals = Get number of intervals... 'tier'
 for currentInterval from 1 to 'numIntervals'
  currentIntervalLabel$ = Get label of interval... 'tier' 'currentInterval'
  if currentIntervalLabel$==interval_label$
   intervalOfInterest = currentInterval
  endif
 endfor
endif

startTime = Get starting point... 'tier' 'intervalOfInterest'
endTime = Get end point... 'tier' 'intervalOfInterest'
### (end time domain check)

###
### Third, decide what times to measure at.
###

d = startTime
## If equidistant points: compute based on number of points
if measure = 1
    diff = (endTime - startTime) / (timepoints+1)
## If absolute: take a measurement every timepoints/1000 points
elsif measure = 2
    diff = timestep / 1000
endif
for point from 1 to timepoints
    mid'point' = d
    d = d + diff
endfor
### (end time point selection)

###
### Fourth, build Matrix object to hold results
### columns 1-2 hold timepoints of the measurement 
### (col 2 relative to distance from startTime)
### columns 3-21 hold spectral measures
if outputToMatrix
    Create simple Matrix... IseliMeasures timepoints 21 0
    matrixID = selected("Matrix")
endif
### (end build matrix object) ###

### Resample ###
### Why? I think because VoiceSauce does
select 'soundID_orig'
sample_rate = 16000
Resample... 'sample_rate' 50
soundID = selected("Sound")

### Create Harmonicity objects (once) ###
select 'soundID'
#To Harmonicity (cc): 0.01, 50, 0.1, 1.0
#hnrID = selected ("Harmonicity")
select 'soundID'
Filter (pass Hann band): 0, 500, 100
Rename... 'name$'_500
To Harmonicity (cc): 0.01, 50, 0.1, 1.0
hnr05ID = selected ("Harmonicity")
select 'soundID'
Filter (pass Hann band): 0, 1500, 100
Rename... 'name$'_1500
To Harmonicity (cc): 0.01, 50, 0.1, 1.0
hnr15ID = selected ("Harmonicity")
select 'soundID'
Filter (pass Hann band): 0, 2500, 100
Rename... 'name$'_2500
To Harmonicity (cc): 0.01, 50, 0.1, 1.0
hnr25ID = selected ("Harmonicity")
select 'soundID'
Filter (pass Hann band): 0, 3500, 100
Rename... 'name$'_3500
To Harmonicity (cc): 0.01, 50, 0.1, 1.0
hnr35ID = selected ("Harmonicity")
### (end create Harmonicity objects ###

for i from 1 to timepoints

	## Generate a slice around the measurement point ##
	sliceStart = mid'i' - ('windowLength' / 2)
	sliceEnd = mid'i' + ('windowLength' / 2)

	############################
	# Create slice-based objects 
	############################
	select 'soundID'
	Extract part... 'sliceStart' 'sliceEnd' Hanning 1 yes
	windowedSoundID = selected("Sound")
	To Spectrum... yes
	spectrumID = selected("Spectrum")
	To Ltas (1-to-1)
	ltasID = selected("Ltas")
	select 'spectrumID'
	To PowerCepstrum
	cepstrumID = selected("PowerCepstrum")

	################
	# Get F1, F2, F3
	################
    select 'formantID'
	f1hzpt = Get value at time... 1 mid'i' Hertz Linear
	f1bw = Get bandwidth at time... 1 mid'i' Hertz Linear
	f2hzpt = Get value at time... 2 mid'i' Hertz Linear
	f2bw = Get bandwidth at time... 2 mid'i' Hertz Linear
	xx = Get minimum number of formants
	if xx > 2
		f3hzpt = Get value at time... 3 mid'i' Hertz Linear
		f3bw = Get bandwidth at time... 3 mid'i' Hertz Linear
	else
		f3hzpt = 0
		f3bw = 0
	endif

	####################
	# Measure H1, H2, H4
	####################
	select 'pitchID'
    # pitch estimate at timepoint i
    n_f0md = Get value at time... mid'i' Hertz Linear
    # this gives a way to compute the bandwidth based on f0
    # if f0 is undefined no point in doing any of this
    if n_f0md <> undefined
	    p10_nf0md = 'n_f0md' / 10

        # ltasID is a slice based on i and the window size
        select 'ltasID'
        lowerbh1 = n_f0md - p10_nf0md
        upperbh1 = n_f0md + p10_nf0md
        lowerbh2 = (n_f0md * 2) - (p10_nf0md * 2)
        upperbh2 = (n_f0md * 2) + (p10_nf0md * 2)
        lowerbh4 = (n_f0md * 4) - (p10_nf0md * 2)
        upperbh4 = (n_f0md * 4) + (p10_nf0md * 2)
        h1db = Get maximum... 'lowerbh1' 'upperbh1' None
        #h1db = Get value at frequency... 'n_f0md' Nearest
#        h1hz = Get frequency of maximum... 'lowerbh1' 'upperbh1' None
        h2db = Get maximum... 'lowerbh2' 'upperbh2' None
        #h2db = Get value at frequency... 2*'n_f0md' Nearest
#        h2hz = Get frequency of maximum... 'lowerbh2' 'upperbh2' None
        h4db = Get maximum... 'lowerbh4' 'upperbh4' None
        #h4db = Get value at frequency... 4*'n_f0md' Nearest
#        h4hz = Get frequency of maximum... 'lowerbh4' 'upperbh4' None

        #################
        # Measure A1, A2, A3 
        #################
        p10_f1hzpt = 'f1hzpt' / 10
        p10_f2hzpt = 'f2hzpt' / 10
        p10_f3hzpt = 'f3hzpt' / 10
        lowerba1 = 'f1hzpt' - 'p10_f1hzpt'
        upperba1 = 'f1hzpt' + 'p10_f1hzpt'
        lowerba2 = 'f2hzpt' - 'p10_f2hzpt'
        upperba2 = 'f2hzpt' + 'p10_f2hzpt'
        lowerba3 = 'f3hzpt' - 'p10_f3hzpt'
        upperba3 = 'f3hzpt' + 'p10_f3hzpt'
        #a1db = Get value at frequency... 'f1hzpt' Nearest
        a1db = Get maximum... 'lowerba1' 'upperba1' None
       #a1hz = Get frequency of maximum... 'lowerba1' 'upperba1' None
        #a2db = Get value at frequency... 'f2hzpt' Nearest
        a2db = Get maximum... 'lowerba2' 'upperba2' None
       #a2hz = Get frequency of maximum... 'lowerba2' 'upperba2' None
        #a3db = Get value at frequency... 'f3hzpt' Nearest
        a3db = Get maximum... 'lowerba3' 'upperba3' None
       #a3hz = Get frequency of maximum... 'lowerba3' 'upperba3' None
                                
        #################################
        # Calculate adjustments relative to F1-F3
        #################################
        #
        # the way it was done here was to use the maximum frequences in the windows
        # the way VoiceSauce does it is based solely on the F0 estimate of the timepoint
        # (h1hz, a1hz, etc)
        #
        # correct H1 for effects of first 2 formants
        @correct_iseli_z (n_f0md, f1hzpt, f1bw, sample_rate)
        h1adj = h1db - correct_iseli_z.result
        @correct_iseli_z (n_f0md, f2hzpt, f2bw, sample_rate)
        h1adj = h1adj - correct_iseli_z.result
        # correct H2 for effects of first 2 formants
        @correct_iseli_z (2*n_f0md, f1hzpt, f1bw, sample_rate)
        h2adj = h2db - correct_iseli_z.result
        @correct_iseli_z (2*n_f0md, f2hzpt, f2bw, sample_rate)
        h2adj = h2adj - correct_iseli_z.result
        # correct H4 for effects of first 2 formants
        @correct_iseli_z (4*n_f0md, f1hzpt, f1bw, sample_rate)
        h4adj = h4db - correct_iseli_z.result
        @correct_iseli_z (4*n_f0md, f2hzpt, f2bw, sample_rate)
        h4adj = h4adj - correct_iseli_z.result
        # correct A1 for effects of first 2 formants
        @correct_iseli_z (f1hzpt, f1hzpt, f1bw, sample_rate)
        a1adj = a1db - correct_iseli_z.result
        @correct_iseli_z (f1hzpt, f2hzpt, f2bw, sample_rate)
        a1adj = a1adj - correct_iseli_z.result
        # correct A2 for effects of first 2 formants
        @correct_iseli_z (f2hzpt, f1hzpt, f1bw, sample_rate)
        a2adj = a2db - correct_iseli_z.result
        @correct_iseli_z (f2hzpt, f2hzpt, f2bw, sample_rate)
        a2adj = a2adj - correct_iseli_z.result
        # correct A3 for effects of first 3 formants
        @correct_iseli_z (f3hzpt, f1hzpt, f1bw, sample_rate)
        a3adj = a3db - correct_iseli_z.result
        @correct_iseli_z (f3hzpt, f2hzpt, f2bw, sample_rate)
        a3adj = a3adj - correct_iseli_z.result
        @correct_iseli_z (f3hzpt, f3hzpt, f3bw, sample_rate)
        a3adj = a3adj - correct_iseli_z.result

        ## correcting for all 3 formants for everything
        #@correct_iseli (h1db, h1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #h1adj = correct_iseli.result
        #@correct_iseli (h2db, h2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #h2adj = correct_iseli.result
        #@correct_iseli (h4db, h4hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #h4adj = correct_iseli.result
        #@correct_iseli (a1db, a1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #a1adj = correct_iseli.result
        #@correct_iseli (a2db, a2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #a2adj = correct_iseli.result
        #@correct_iseli (a3db, a3hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
        #a3adj = correct_iseli.result

    else
    # can't store undefineds in Praat Matrices
        h1db = 0
        h2db = 0
        h4db = 0
        a1db = 0
        a2db = 0
        a3db = 0
        h1adj = 0
        h2adj = 0
        h4adj = 0
        a1adj = 0
        a2adj = 0
        a3adj = 0
    endif

    # if for some reason couldn't get a3adj...
    if (a3adj = undefined)
        a3adj = 0
    endif

	###########################
    # Cepstral peak prominence
	###########################
    select 'cepstrumID'
    cpp = Get peak prominence... 'f0min' 'f0max' "Parabolic" 0.001 0 "Straight" Robust
    Smooth... 0.0005 1
    smoothed_cepstrumID = selected("PowerCepstrum")
    cpps = Get peak prominence... 'f0min' 'f0max' "Parabolic" 0.001 0 "Straight" Robust

	#############
    # H2k and H5k 
	#############
    # search window--harmonic location should be based on F0, but would throw out a lot. Will base it on cepstral peak.
    select 'cepstrumID'
    peak_quef = Get quefrency of peak: 50, 550, "Parabolic"
    peak_freq = 1/peak_quef
    lowerb2k = 2000 - peak_freq
    upperb2k = 2000 + peak_freq
    lowerb5k = 5000 - peak_freq
    upperb5k = 5000 + peak_freq
    select 'ltasID'
    twokdb = Get maximum: lowerb2k, upperb2k, "Cubic"
    fivekdb = Get maximum: lowerb5k, upperb5k, "Cubic"
   
	########################## 
    # Harmonic-to-noise ratios
	########################## 
    select 'hnr05ID'
    hnr05db = Get value at time: mid'i', "Cubic"
    select 'hnr15ID'
    hnr15db = Get value at time: mid'i', "Cubic"
    select 'hnr25ID'
    hnr25db = Get value at time: mid'i', "Cubic"
    select 'hnr35ID'
    hnr35db = Get value at time: mid'i', "Cubic"
                    
	if outputToMatrix
		select 'matrixID'
        # find time of measurement, relative to startTime
        #absPoint = mid'i' - startTime
        
        ## set first value to ms time
        #Set value... i 1 absPoint
        Set value... i 1 mid'i'

        ## set subsequent value to measurements
		Set value... i 2 'h1db'
		Set value... i 3 'h2db'
		Set value... i 4 'h4db'
		Set value... i 5 'a1db'
		Set value... i 6 'a2db'
		Set value... i 7 'a3db'
		Set value... i 8 'h1adj'
		Set value... i 9 'h2adj'
		Set value... i 10 'h4adj'
		Set value... i 11 'a1adj'
		Set value... i 12 'a2adj'
		Set value... i 13 'a3adj'
		Set value... i 14 'twokdb'
		Set value... i 15 'fivekdb'
		Set value... i 16 'cpp'
		Set value... i 17 'cpps'
		Set value... i 18 'hnr05db'
		Set value... i 19 'hnr15db'
		Set value... i 20 'hnr25db'
		Set value... i 21 'hnr35db'
	else
        printline "'name$''tab$''h1db''tab$''h2db''tab$''h4db''tab$''a1db''tab$''a2db''tab$''a3db''tab$''h1adj''tab$''h2adj''tab$''h4adj''tab$''a1adj''tab$''a2adj''tab$''a3adj''tab$''twokdb''tab$''fivekdb''tab$''cpp''tab$''cpps''tab$''hnr05db''tab$''hnr15db''tab$''hnr25db''tab$''hnr35db'"
	endif
	## end of outputToMatrix

	###
	# Clean up generated objects
	###
	select 'windowedSoundID'
	plus 'spectrumID'
	plus 'ltasID'
	Remove

    select 'soundID_orig'
	plus 'textGridID'
	plus 'formantID'
endfor


#################################################
## adapted from VoiceSauce func_correct_iseli_z.m
## version 1.27
#################################################

procedure correct_iseli_z (f, fx, bx, fs) 
   r = exp(-pi*bx/fs)
   omega_x = 2*pi*fx/fs
   omega  = 2*pi*f/fs
   a = r ^ 2 + 1 - 2*r*cos(omega_x + omega)
   b = r ^ 2 + 1 - 2*r*cos(omega_x - omega)
   corr = -10*(log10(a)+log10(b));   # not normalized: H(z=0)~=0
   numerator = r ^ 2 + 1 - 2 * r * cos(omega_x)
   corr = -10*(log10(a)+log10(b)) + 20*log10(numerator)
   .result = corr
endproc

###############################################################
## Collier's 'original' adaptation of the procedure
## from praat_voice_measures.praat, itself a modification of
## praatvoicesauceimitator.praat by Chad Vicenik
###############################################################

## the issue with this is, viz-a-vis the VoiceSauce function,
## for a given magnitude, it doesn't hold the frequency constant.
## the fx variable is changed on each pass through the loop.
## judging from the VoiceSauce script, the same frequency (F0, 2*F0, 
## F1, F2, F3...) is passed to each run of the script - it is only
## the formant frequency and bandwidth that change.

## he seems to have anticipated this by passing hz in but...
## 'hz' is never referenced, and f is set to dB(c) for some reason

procedure correct_iseli (dB, hz, f1hz, f1bw, f2hz, f2bw, f3hz, f3bw, fs)
    dBc = dB
    for corr_i from 1 to 3
        fx = f'corr_i'hz
        bx = f'corr_i'bw
        f = dBc
        if fx <> 0
            r = exp(-pi*bx/fs)
            omega_x = 2*pi*fx/fs
            omega  = 2*pi*f/fs
            a = r ^ 2 + 1 - 2*r*cos(omega_x + omega)
            b = r ^ 2 + 1 - 2*r*cos(omega_x - omega)
            corr = -10*(log10(a)+log10(b));   # not normalized: H(z=0)~=0

            numerator = r ^ 2 + 1 - 2 * r * cos(omega_x)
            corr = -10*(log10(a)+log10(b)) + 20*log10(numerator)
            dBc = dBc - corr
        endif
    endfor
    .result = dBc
endproc

