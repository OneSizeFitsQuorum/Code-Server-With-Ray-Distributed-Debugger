# Documentation and Tests for fsspec PR #1944

This directory contains the enhanced documentation and test cases for [fsspec PR #1944](https://github.com/fsspec/filesystem_spec/pull/1944).

## Overview

PR #1944 updates the `set_size()` method in `fsspec/callbacks.py` to accept callable parameters in addition to integer values. This change is necessary to handle filesystem objects that have a `size()` method instead of a `size` attribute.

## Changes Made

### 1. Enhanced Documentation (callbacks.py)

The `set_size()` method documentation has been significantly improved to include:

- **Detailed parameter description**: Explains that `size` can be either an int or a callable
- **Use case explanation**: Describes when the callable option is useful (e.g., when filesystem objects have a `size()` method)
- **Examples**: Provides clear examples of both integer and callable usage
- **Notes section**: Clarifies the behavior when a callable is provided

### 2. New Test Case (test_callbacks.py)

Added `test_set_size_with_callable()` which thoroughly tests the callable functionality:

- **Integer parameter test**: Verifies existing behavior with direct integer values
- **Lambda function test**: Tests with lambda expressions
- **Function reference test**: Tests with regular function references
- **Method reference test**: Tests the actual use case - passing a method that returns size (simulates filesystem objects)

## Test Results

All tests pass successfully:

```
fsspec/tests/test_callbacks.py::test_set_size_with_callable PASSED
```

The new test covers the following scenarios:
1. Setting size with an integer (backward compatibility)
2. Setting size with a lambda function
3. Setting size with a named function
4. Setting size with a method from an object (primary use case for this feature)

## How to Apply These Changes

These files can be used to update the PR #1944:

1. Replace `fsspec/callbacks.py` in the PR branch with the version in this directory
2. Replace `fsspec/tests/test_callbacks.py` in the PR branch with the version in this directory
3. Run tests to verify: `pytest fsspec/tests/test_callbacks.py -v`

## Background

The change was needed because some filesystem implementations (like `HadoopFileSystem` which inherits from `ArrowFSWrapper`) have a `size()` method instead of a `size` attribute. When using `getattr(f, "size", None)` on such objects, it returns a callable function rather than an integer value. The enhanced `set_size()` method now handles this case automatically by detecting and calling the function if needed.

## Related Links

- [PR #1944](https://github.com/fsspec/filesystem_spec/pull/1944)
- [fsspec callbacks.py](https://github.com/fsspec/filesystem_spec/blob/master/fsspec/callbacks.py)
- [fsspec spec.py (where the issue occurs)](https://github.com/fsspec/filesystem_spec/blob/master/fsspec/spec.py#L937)
