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

1) Converting the station name into a NSString (~44% of samples):
```
1135 main  (in calc_1brc) + 816  [0x1058f1659]  main.m:75
+ 958 +[NSString stringWithUTF8String:]  (in Foundation) + 68  [0x7ff8044f35c7]
  (only other call worth mentioning was from objc_msgSend calls @ 74 samples)
     V
translates to
     V
NSString * name = [NSString stringWithUTF8String:nameBuf.characters];
```

2) Getting the datamodel from the dictionary storage (~22% of time):
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



