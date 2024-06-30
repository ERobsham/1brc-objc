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



