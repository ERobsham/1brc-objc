#  One Billion Row Challenge - Objc

Have been seeing/hearing a decent amout of buzz around this challenge.  Rather than installing a whole JVM & IDE just to take a pass at it, I figured id give it a go in another (in?)famously object orientented language.

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

## Initial implementation overview:

Shooting for a fairly 'vanilla' impelmentation:
 * use NSInputStream for fetching raw data from the measurements file (since theres no possible way to load a 14+ gb file into my 8gb of RAM).
 * parse raw data using just plain `c` style char[] iteration.
 * wrap parsed data in a minimal objective-c `StationEntry` data model class, storing results in NSMutableDictionary, keyed by the station name.
 * finally, once fully parsed. sort keys and output formatted results.
 * single-thread.  No specific optimizations.

### Initial results (`6459d5`):

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


### Round 2 - less obj, more c - results (`d1bc89`):

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


