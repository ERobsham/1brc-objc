#  One Billion Row Challenge - Objc

Have been seeing/hearing a decent amount of buzz around this challenge.  Rather than installing a whole JVM & IDE just to take a pass at it, I figured id give it a go in another (in?)famously object orientated language.

Its a language I end up spending a lot of time interacting with at work maintaining a large legacy codebase of objc.  Based on my experience thus far I expect it will be a good challenge to get any kind of decent performance out of essentially the `javascript` of compiled languages.  But I figured it'd probably be fun to try anyways..!     

## Rules:
* Input value ranges are as follows:
    * Station name: non null UTF-8 string of min length 1 character and max length 100 bytes, containing neither ; nor \n characters. (i.e. this could be 100 one-byte characters, or 50 two-byte characters, etc.)
    * Temperature value: non null double between -99.9 (inclusive) and 99.9 (inclusive), always with one fractional digit
* There is a maximum of 10,000 unique station names
* Line endings in the file are \n characters on all platforms
* Implementations must not rely on specifics of a given data set, e.g. any valid station name as per the constraints above and any data distribution (number of measurements per station) must be supported
* The rounding of output values must be done using the semantics of IEEE 754 rounding-direction "roundTowardPositive"

Output example:
```
{Abha=-23.0/18.0/59.2, Abidjan=-16.2/26.0/67.3, Abéché=-10.0/29.4/69.0, Accra=-10.1/26.4/66.4, Addis Ababa=-23.7/16.0/67.0, Adelaide=-27.8/17.3/58.5, ...}
```

Test runner specs:
2017 iMac / 3.6ghz Quad Core i7 / 8gb RAM.

# Results

## Initial implementation overview (`6459d5`):

Shooting for a fairly 'vanilla' implementation:
 * use NSInputStream for fetching raw data from the measurements file (since theres no possible way to load a 14+ gb file into my 8gb of RAM).
 * parse raw data using just plain `c` style char[] iteration.
 * wrap parsed data in a minimal objective-c `StationEntry` data model class, storing results in NSMutableDictionary, keyed by the station name.
 * finally, once fully parsed. sort keys and output formatted results.
 * single-thread.  No specific optimizations.

### Initial results:

Horrible performance 0/10: `314.92s user 7.14s system 98% cpu 5:27.95 total`
Taking a process sample, a few things stood out:
```
Call graph:
    2580 Thread_3298614   DispatchQueue_1: com.apple.main-thread  (serial)
      2580 start  (in dyld) + 1903  [0x7ff80326c41f]
        1135 main  (in calc_1brc) + 816  [0x1058f1659]  main.m:75
        + 958 +[NSString stringWithUTF8String:]  (in Foundation) + 68  [0x7ff8044f35c7]
        ...
        561 main  (in calc_1brc) + 854  [0x1058f167f]  main.m:76
        + 238 -[__NSDictionaryM objectForKeyedSubscript:]  (in CoreFoundation) + 172  [0x7ff80366b32e]
        ...
        245 main  (in calc_1brc) + 1077  [0x1058f175e]  main.m:86
        + 131 _CFRelease  (in CoreFoundation) + 1402  [0x7ff80376ff41]
        ...
        194 main  (in calc_1brc) + 680,640,...  [0x1058f15d1,0x1058f15a9,...]  main.m:71
        147 main  (in calc_1brc) + 862  [0x1058f1687]  main.m:76
        + 145 objc_retain  (in libobjc.A.dylib) + 22,80,...  [0x7ff8032310a6,0x7ff8032310e0,...]
```

Lets break that down a bit.   So from the total of 2580 samples, these are a few of the big hitters.

1) Converting the station name into a NSString (~44%):
```
1135 main  (in calc_1brc) + 816  [0x1058f1659]  main.m:75
+ 958 +[NSString stringWithUTF8String:]  (in Foundation) + 68  [0x7ff8044f35c7]
  (only other call worth mentioning was from objc_msgSend calls @ 74 samples)
     V
translates to
     V
NSString * name = [NSString stringWithUTF8String:nameBuf.characters];
```

2) Getting the datamodel from the dictionary storage (~22%):
```
561 main  (in calc_1brc) + 854  [0x1058f167f]  main.m:76
+ 238 -[__NSDictionaryM objectForKeyedSubscript:]  
  (519 if counting all instances of this method, remaining ~40+ are from -hash / objc_msgSend calls)
     V
translates to
     V
StationEntry * entry = stationInfo[name];
```

3) Objc overhead -- release (~9.5%):
```
245 main  (in calc_1brc) + 1077  [0x1058f175e]  main.m:86
+ 131 _CFRelease  (in CoreFoundation) + 1402  [0x7ff80376ff41]
  (245 if counting every variation of a release function/method call)
     V
translates to the end of scope on the 'line parsing' while loop.
```

4) actual data parsing (~7.5%):
```
194 main  (in calc_1brc) + 680,640,...  [0x1058f15d1,0x1058f15a9,...]  main.m:71
     V
translates to
     V
while ((lineOffset = parseLine(&buf[offset], &nameBuf, &temp)) > 0) {
```


5) More objc overhead -- retain (~5.5%):
```
147 main  (in calc_1brc) + 862  [0x1058f1687]  main.m:76
+ 145 objc_retain  (in libobjc.A.dylib) + 22,80,...  [0x7ff8032310a6,0x7ff8032310e0,...]
```

#### Takeaways:

Using objc/fully heap allocated memory to parse data is ... _less than ideal_.  During more than 80% of the samples we were either waiting on memory to be created to store the station name, or awaiting retrieval of the data model from the NSDictionary.   Also somewhat hilariously, we're seeing double the amount of samples in calls handling ARC than we were seeing in calls actually doing to work to parse the data..!

Disclaimer:  where this took almost 5.5mins to complete, this was only data from a single run -- its quite possible the total time number could vary a good amount, however I did take fair number of process samples, all with relatively close distribution of the high level calls


## Round 2 - less obj, more c - implementation overview (`d1bc89`):

Notable changes:
 * skip wrapping the raw data in objc types during row parsing and just keep track of them in C structs.
 * downside: using a _very_ naive 'hash' for the station names that is used to index into their cumulative results. 
   Assuming some stations data is certainly getting merged together. Choosing to ignoring this for now, where I'm more interested in just the time it takes to parse.

### less obj, more c results:

Not great performance, but _muuuch_ better than original: `40.12s user 5.76s system 90% cpu 50.458 total`
This time I was patient enough to run a few cycles, all falling within the 50 sec +/- a few tenths of a second. 

Now after reviewing a process sample, things look like we're actually parsing the data most of the time:
```
Call graph:
    2511 Thread_3425997   DispatchQueue_1: com.apple.main-thread  (serial)
      2511 start  (in dyld) + 1903  [0x7ff80326c41f]
        1643 main  (in calc_1brc) + 496,577,...  [0x10b70b4ef,0x10b70b540,...]  main.m:82
        395 main  (in calc_1brc) + 914  [0x10b70b691]  main.m:71
        + ...
        248 main  (in calc_1brc) + 698,690  [0x10b70b5b9,0x10b70b5b1]  main.m:87
        104 main  (in calc_1brc) + 708,715,...  [0x10b70b5c3,0x10b70b5ca,...]  main.m:107
        38 main  (in calc_1brc) + 795  [0x10b70b61a]  main.m:105
        34 main  (in calc_1brc) + 676,686  [0x10b70b5a3,0x10b70b5ad]  main.m:86
        21 main  (in calc_1brc) + 700,802  [0x10b70b5bb,0x10b70b621]  main.m:106
        18 main  (in calc_1brc) + 669,673,...  [0x10b70b59c,0x10b70b5a0,...]  main.m:0
        8 main  (in calc_1brc) + 784,787  [0x10b70b60f,0x10b70b612]  main.m:104
        1 main  (in calc_1brc) + 866  [0x10b70b661]  main.m:113
        1 main  (in calc_1brc) + 369  [0x10b70b470]  main.m:77
```

Next up from the 2511 samples, the new heavy hitters are as follows:

1) `parseLine()` (~65%):
```
1643 main  (in calc_1brc) + 496,577,...  [0x10b70b4ef,0x10b70b540,...]  main.m:82
     V
translates to
     V
while ((lineOffset = parseLine(&buf[offset], &nameBuf, &temp)) > 0) {
```

2) `-read:maxLength:` (~16%):
```
395 main  (in calc_1brc) + 914  [0x10b70b691]  main.m:71
     V
translates to
     V
while ((bytesRead = [stream read:&buf[leftover]
                       maxLength:remainingLen]) > 0) {
```

3) the `stationList` 'is initialized' check (~10%):
```
248 main  (in calc_1brc) + 698,690  [0x10b70b5b9,0x10b70b5b1]  main.m:87
     V
translates to
     V
if (entry->name.characters[0] == 0) {
```


#### Takeaways:

This is more like it, most of the time spent actually turning raw bytes into meaningful data!  Im assuming we're getting all the static function calls inlined, so `parseLine()` is getting weighted extra heavy.  We'll need to do some forced _not inlining_ to get better granularity on which of the parsing bits we could speed up from here.

We're actually getting the data reading to actually show up on the charts now, so we might be able to do something like split the logic into one thread that reads in data to a set buffers, while a few the other threads parse the data.  

Lastly, Seems like we're getting a measurable performance hit dereferencing a value from the `stationEntry stationList[NUM_STATIONS] = {0};` array of structs.
My best guess right now would be its such a large chunk of data, and the 'station name key' are accessed randomly, so even though this is an O(1) lookup, we're running into cache misses, and causing some slowdowns there. 


## Round 3 - parallelize - implementation overview (`1d3fd6`):

The parallelization changing over adds a single `BRCCoordinator` instance that starts up a single `BRCFileReader`, and a few `BRCWorkers`.

The `BRCFileReader` handles loading data into buffers, which it adds to a list of buffers that are loaded and ready to hand off to worker threads.  Upon initialization it takes the current thread as its 'work thread' and preloads all its buffers, in preparation for workers to start requesting chunks.
The `BRCFileReader` primarily runs on a single thread and handles trimming any 'partial' data off the end of a buffer (looking for the first `\n` from the end), and appending it to the beginning of the next buffer before continuing to read from the `NSInputStream`, and adding that chunk into its list of buffers available for other threads to grab.  Having the centralized reader, which only loads buffers on the main thread makes handling this 'chunking' nice and easy, so workers don't have to worry about reporting back 'leftover' data they didn't consume.

The `BRCWorker` instances detach their own background threads and immediately start running. Once the `BRCDataLoader` service they were initialized with returns a `nil` response when requesting more data to work on, they exit their background thread.

Finally `BRCCoordinator` would just spin the runloop (which `BRCFileReader` depends on) awaiting all the `BRCWorker` instances it spun up to finish.


### parallelize results:

Still not _amazing_, but getting acceptable results considering the machine/language combo I'm using: `49.73s user 6.99s system 432% cpu 13.117 total`.
And the results times for this iteration were definitely much more dependent on what other tasks were running (ie, while Chrome, Xcode, and VSCode were running, that number shot up to over 17sec). However, if I exclusively ran the test in a single terminal window with no other applications in the background, solidly getting ~13 sec runs.

And this time the process sample is showing the 'read' thread is mostly idle (in the process of reading the file in for just over 25% of the samples):
```
Call graph:
    1963 Thread_24765   DispatchQueue_1: com.apple.main-thread  (serial)
    + 1963 start  (in dyld) + 1903  [0x7ff8143c741f]
    +   1963 main  (in calc_1brc) + 219  [0x1026664ea]  main.m:34
    +     1963 -[BRCCoordinator run]  (in calc_1brc) + 1002  [0x1026650fd]  BRCCoordinator.m:59
    +       1963 -[NSRunLoop(NSRunLoop) runMode:beforeDate:]  (in Foundation) + 216  [0x7ff8156890e3]
    +         1963 CFRunLoopRunSpecific  (in CoreFoundation) + 560  [0x7ff8147fbeb1]
    +           1437 __CFRunLoopRun  (in CoreFoundation) + 1365  [0x7ff8147fca70]
                      ...
    +           !         1437 mach_msg2_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8146e3552]
    +           526 __CFRunLoopRun  (in CoreFoundation) + 916  [0x7ff8147fc8af]
    +             526 __CFRunLoopDoSources0  (in CoreFoundation) + 217  [0x7ff8147fdc25]
    +               526 __CFRunLoopDoSource0  (in CoreFoundation) + 157  [0x7ff8147fde4c]
    +                 526 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__  (in CoreFoundation) + 17  [0x7ff8147fdeaa]
    +                   525 __NSThreadPerformPerform  (in Foundation) + 177  [0x7ff8156a95b3]
    +                   : 524 -[BRCFileReader returnChunk:]  (in calc_1brc) + 207  [0x102666187]  BRCFileReader.m:147
    +                   : | 524 -[BRCFileReader loadNextChunkInto:]  (in calc_1brc) + 262  [0x102665ded]  BRCFileReader.m:87
                        ...
```

But the work threads are crunching even harder, exposing some more bottlenecks.  The main parsing takes up just over 50% of all samples, the 'station is initialized' check takes close to 25% of all samples now, and _almost_ shockingly even having the workers use a _non-atomic_ property to track the number if lines they've parsed it takes almost 10% of all samples to do a simple `+= 1`increment:
```
1963 Thread_24784
    + 1963 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff81471dbd3]
    +   1963 _pthread_start  (in libsystem_pthread.dylib) + 125  [0x7ff8147221d3]
    +     1963 __NSThread__start__  (in Foundation) + 1009  [0x7ff815682393]
    +       1025 -[BRCWorker runLoop]  (in calc_1brc) + 310,380,...  [0x102664704,0x10266474a,...]  BRCWorker.m:69
    +       464 -[BRCWorker runLoop]  (in calc_1brc) + 575,571  [0x10266480d,0x102664809]  BRCWorker.m:74
    +       167 -[BRCWorker runLoop]  (in calc_1brc) + 580,586,...  [0x102664812,0x102664818,...]  BRCWorker.m:96
    +       134 -[BRCWorker runLoop]  (in calc_1brc) + 525  [0x1026647db]  BRCWorker.m:71
    +       ! 121 objc_msgSend  (in libobjc.A.dylib) + 46,33,...  [0x7ff81438c22e,0x7ff81438c221,...]
    +       ! 13 -[BRCWorker linesRead]  (in calc_1brc) + 0,10  [0x102664ab8,0x102664ac2]  BRCWorker.h:27
    +       71 -[BRCWorker runLoop]  (in calc_1brc) + 547  [0x1026647f1]  BRCWorker.m:71
    +       ! 56 objc_msgSend  (in libobjc.A.dylib) + 46,37,...  [0x7ff81438c22e,0x7ff81438c225,...]
    +       ! 14 -[BRCWorker setLinesRead:]  (in calc_1brc) + 10,0  [0x102664ace,0x102664ac4]  BRCWorker.m:35
    +       ! 1 -[BRCWorker setLinesRead:]  (in calc_1brc) + 4  [0x102664ac8]  BRCWorker.m:0
    +       47 -[BRCWorker runLoop]  (in calc_1brc) + 657,475,...  [0x10266485f,0x1026647a9,...]  BRCWorker.m:0
    +       22 -[BRCWorker runLoop]  (in calc_1brc) + 577,667,...  [0x10266480f,0x102664869,...]  BRCWorker.m:95
    +       17 -[BRCWorker runLoop]  (in calc_1brc) + 516,531,...  [0x1026647d2,0x1026647e1,...]  BRCWorker.m:71
    +       8 -[BRCWorker runLoop]  (in calc_1brc) + 552,549,...  [0x1026647f6,0x1026647f3,...]  BRCWorker.m:73
    +       4 -[BRCWorker runLoop]  (in calc_1brc) + 653  [0x10266485b]  BRCWorker.m:93
    +       3 -[BRCWorker runLoop]  (in calc_1brc) + 810  [0x1026648f8]  BRCWorker.m:61
    +       ! 3 -[BRCFileReader nextChunk]  (in calc_1brc) + 419  [0x10266607f]  BRCFileReader.m:136
    +       !   3 usleep  (in libsystem_c.dylib) + 53  [0x7ff8145d84bb]
    +       !     3 nanosleep  (in libsystem_c.dylib) + 196  [0x7ff8145d8585]
    +       !       3 __semwait_signal  (in libsystem_kernel.dylib) + 10  [0x7ff8146e5f5e]
    +       1 -[BRCWorker runLoop]  (in calc_1brc) + 664  [0x102664866]  BRCWorker.m:94
```

#### Takeaways:

The problem is actually being completed before I have the urge to walk away, so we've made some good progress.  I wasn't expecting great things from objc in general, but I think it does a great job of highlighting its many weaknesses and one strength -- its dynamically typed, dynamically dispatched, entirely heap allocated, slow which make it a terrible choice for this challenge.  But its really fairly good at making threaded interfaces easy to use, and where its a pure `C` extension, that access to an easy mechanism to pass data between threads can be leveraged to wrap some lower level C data manipulation, and still get some _fairly_ decent results out of it.


## Wrapping up

I think pushing this much further would be a bit painful, and I think trying this out in a different language which is more performant at a baseline would be where Id prefer to spend my time.

Either way, taking this from a base runtime of ~6.5mins down to under 15sec has been a fun little experiment.  I think the next time, I might tackle this in `go`. While not being the _best_ choice for this kind of challenge, but just being a decent step up in baseline speed, with new challenges to overcome (ie, minimizing the garbage collection impact and avoiding hoisting variables into the heap, etc).
