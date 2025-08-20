You have been pointed to a specific test that's failing. You must identify the exact point the test is failing at.

- Create a dedicated test file which is a verbatim identical copy of the failing test. DO NOT SIMPLIFY THE TEST! YOU HAVE NO IDEA WHAT WILL EFFECT THE BEHAVIOUR!
- Verify that your copy is failing with the same error.
- Add debug statements for every stage of the test, and use them to identify a point where something is going wrong.
- When something looks wrong, expand the function calls right before that point based on the implementation definitions.
- Verify that nothing in the output has changed after the expansion.
- Add new debug statements between the different steps of the expanded region, and identify where it goes wrong.
- Repeat the last 4 steps until you've drilled down to the exact point of failure.

DO NOT get distracted by other ideas or speculations durring this. You're only goal is to create a microscope on the exact point of failure.
