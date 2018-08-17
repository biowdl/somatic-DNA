/*
 * Copyright (c) 2018 Biowdl
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package biowdl.test.strelka

import java.io.File

import nl.biopet.utils.biowdl.fixtureFile
import nl.biopet.utils.biowdl.references.TestReference

class StrelkaTestUnpaired extends StrelkaSuccess with TestReference {
  def tumorBam: File = fixtureFile("samples", "wgs2", "wgs2.realign.bam")

  override def truth: File = fixtureFile("samples", "wgs2", "wgs2.vcf.gz")
}

class StrelkaTestPaired extends StrelkaTestUnpaired {
  override def controlBam: Option[File] =
    Option(fixtureFile("samples", "wgs1", "wgs1.bam"))
}

class StrelkaTestUnpairedWithManta extends StrelkaTestUnpaired {
  override def runManta: Boolean = true
}

class StrelkaTestPairedWithManta extends StrelkaTestPaired {
  override def runManta: Boolean = true
}

/* Strelka detects the fact that the same BAM is given twice
class StrelkaTestPairedSameSample extends StrelkaTestUnpaired {
  override def controlBam: Option[File] =
    Option(fixtureFile("samples", "wgs2", "wgs2.realign.bam"))

  override def negativeTest: Boolean = true
}

class StrelkaTestPairedSameSampleWithManta extends StrelkaTestPairedSameSample {
  override def runManta: Boolean = true
}
 */