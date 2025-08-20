Add new tests to reproduce this bug. Make sure the tests integrate with the existing testing infrastructure so they can be run like ordinary tests; don't just make a file demoing the bug.

Come up with 10 possible, different methods to demonstrate the bug with a test. Sort these by viability, and implement the top three as actual tests. REMEMBER: TEST THAT REQUIRE EXTERNAL TOOL CALLS ARE NEVER VIABLE!

- The tests SHOULD BE FAILING since they are detecting a bug. They should flag the bug when running the testing suite. *The tests should be written to expect the correct behavior*
- The tests SHOULD STOP FAILING if the bug is ever fixed. Don't design the test to pass or fail, design the test to pass if the bug is fixed and fail if the bug is present.
- Make sure the test is useful; when it does fail, make sure its able to give all the needed information to see what's structurally wrong. Don't make a test that does something like "Expected True but for False", as that's not very helpful.

The creation of a test that succeeds when a failure is detected is a mortal sin. It's an act of evil. You'd be creating a machine designed for lying. I shouldn't have to explain why that's bad.
