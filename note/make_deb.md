# Building Linux Kernel: `make deb-pkg` vs `make bindeb-pkg`

- Use `make deb-pkg` if you need both binary and source packages, especially for distribution or archival.
- Use `make bindeb-pkg` for streamlined binary builds, ideal for automated pipelines or deployment.

## **1. Overview of the Commands**

| Command            | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `make deb-pkg`     | Builds both binary and source Debian packages.                              |
| `make bindeb-pkg`  | Builds only binary Debian packages using `fakeroot` for proper file ownership. |


## **2. Key Differences**

| Aspect                  | `make deb-pkg`                          | `make bindeb-pkg`                        |
|-------------------------|-----------------------------------------|------------------------------------------|
| Package Type            | Binary + Source                         | Binary only                              |
| Uses `fakeroot`         | ❌ No                                    | ✅ Yes                                    |
| File Ownership          | Files owned by the user                 | Files appear owned by root (standard)    |
| Generated Files         | `.deb`, `.buildinfo`, `.changes`, `.dsc`, `.orig.tar.gz`, `.debian.tar.gz` | `.deb`, `.buildinfo`, `.changes`                              |
| Use Case                | Development, testing, source distribution | CI/CD pipelines, deployment              |


## Extra Files from `make deb-pkg`

When using `make deb-pkg`, the following **source package files** are also generated:

### **1. `.orig.tar.gz`**
- Contains the original upstream source code.
- Used to preserve the unmodified source for reproducibility and upstream tracking.

### **2. `.debian.tar.gz`**
- Contains Debian-specific packaging files and patches.
- Includes the `debian/` directory with metadata like `control`, `rules`, `changelog`, etc.

### **3. `.dsc` (Debian Source Control)**
- Metadata file describing the source package.
- Lists checksums, version, maintainer info, and references to the `.orig.tar.gz` and `.debian.tar.gz`.


### **Purpose of These Files**

These three files together form a **Debian source package**, which can be used to:
- Rebuild the `.deb` packages on other systems.
- Submit the package to Debian or other apt-based repositories.
- Ensure reproducibility and traceability of the build process.
