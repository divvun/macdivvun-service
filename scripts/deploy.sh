fn=macdivvun-`git rev-parse --verify --short HEAD`.txz

tar -C build/MacDivvun.xcarchive/Products/Applications -cf - MacDivvun.service | xz -9 > $fn 
svn import -m "Travis CI file import" $fn $SVN_REPO/$fn
