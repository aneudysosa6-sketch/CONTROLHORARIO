package com.example.controlhorario.face.calibration

import com.example.controlhorario.face.FaceEmbeddingEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceIdentificationCalibrationEvaluatorTest {
    @Test
    fun `computes labeled 1N metrics and data-derived margin candidates`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = sufficientSyntheticSamples(),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        )

        assertEquals(FaceCalibrationStatus.TECHNICAL_SYNTHETIC_EVALUATION, report.status)
        assertEquals(3, report.sampleCount)
        assertEquals(3, report.candidates.size)
        report.samples.first().let { sample ->
            assertFloatEquals(0.90f, sample.genuineScore)
            assertFloatEquals(0.80f, sample.impostorScore)
            assertFloatEquals(0.90f, sample.topScore)
            assertFloatEquals(0.80f, sample.secondScore)
            assertFloatEquals(0.10f, sample.gap)
        }

        val smallestObservedMargin = report.candidates.first()
        assertEquals(0, smallestObservedMargin.falseAccepts)
        assertEquals(0, smallestObservedMargin.falseRejects)
        assertEquals(0.0, smallestObservedMargin.far, 0.0)
        assertEquals(0.0, smallestObservedMargin.frr, 0.0)

        val largestObservedMargin = report.candidates.last()
        assertEquals(0, largestObservedMargin.falseAccepts)
        assertEquals(2, largestObservedMargin.falseRejects)
        assertEquals(1.0, largestObservedMargin.frr, 0.0)
    }

    @Test
    fun `counts accepted wrong identity as false rejection and misidentification`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = listOf(
                sample("known-wrong", "A", "A" to 0.80f, "B" to 0.90f),
                sample("known-right", "B", "A" to 0.78f, "B" to 0.82f),
                sample("unknown", null, "A" to 0.81f, "B" to 0.79f),
            ),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        )

        val smallestObservedMargin = report.candidates.first()
        assertEquals(1, smallestObservedMargin.misidentifications)
        assertEquals(1, smallestObservedMargin.falseRejects)
        assertEquals(0.5, smallestObservedMargin.frr, 0.0)
    }

    @Test
    fun `second score below threshold does not become ambiguous`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = listOf(
                sample("known-low-second", "A", "A" to 0.90f, "B" to 0.70f),
                sample("known-eligible", "B", "A" to 0.80f, "B" to 0.90f),
                sample("unknown", null, "A" to 0.79f, "B" to 0.78f),
            ),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        )

        val largestObservedMargin = report.candidates.last()
        assertEquals(1, largestObservedMargin.falseRejects)
        assertEquals(0.5, largestObservedMargin.frr, 0.0)
    }

    @Test
    fun `multiple templates from one employee cannot occupy top and second`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = listOf(
                templateSample(
                    id = "known-a",
                    expected = "A",
                    templateScore("A", "A-strong", 0.95f),
                    templateScore("A", "A-weaker", 0.94f),
                    templateScore("B", "B-only", 0.80f),
                ),
                templateSample(
                    id = "known-b",
                    expected = "B",
                    templateScore("A", "A-only", 0.79f),
                    templateScore("B", "B-only", 0.90f),
                ),
                templateSample(
                    id = "controlled-impostor",
                    expected = null,
                    templateScore("A", "A-only", 0.82f),
                    templateScore("B", "B-only", 0.78f),
                ),
            ),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        )

        val first = report.samples.first()
        assertFloatEquals(0.95f, first.topScore)
        assertFloatEquals(0.80f, first.secondScore)
        assertFloatEquals(0.15f, first.gap)
    }

    @Test
    fun `reports insufficient data instead of inventing a margin`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = listOf(
                sample("known-only", "A", "A" to 0.90f, "B" to 0.80f),
            ),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        )

        assertEquals(FaceCalibrationStatus.INSUFFICIENT_CALIBRATION_DATA, report.status)
        assertTrue(report.render().contains("status=INSUFFICIENT_CALIBRATION_DATA"))
        assertTrue(report.render().contains("operationalMarginRecommendation=NONE"))
    }

    @Test
    fun `report is readable and excludes synthetic labels and sample identifiers`() {
        val report = FaceIdentificationCalibrationEvaluator.evaluate(
            samples = sufficientSyntheticSamples(),
            matchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        ).render()

        assertTrue(report.contains("genuine="))
        assertTrue(report.contains("impostor="))
        assertTrue(report.contains("top="))
        assertTrue(report.contains("second="))
        assertTrue(report.contains("gap="))
        assertTrue(report.contains("FAR="))
        assertTrue(report.contains("FRR="))
        assertTrue(report.contains("evaluationScope=TECHNICAL_SYNTHETIC_DATA"))
        assertTrue(report.contains("operationalCalibration=FUTURE_REQUIRES_AUTHORIZED_REPRESENTATIVE_DATA"))
        assertTrue(report.contains("operationalMarginRecommendation=NONE"))
        assertFalse(report.contains("known-a"))
        assertFalse(report.contains("subject-A"))
    }

    @Test
    fun `production threshold remains unchanged`() {
        assertFloatEquals(0.75f, FaceEmbeddingEngine.COSINE_THRESHOLD)
    }

    private fun sufficientSyntheticSamples() = listOf(
        sample("known-a", "subject-A", "subject-A" to 0.90f, "subject-B" to 0.80f),
        sample("known-b", "subject-B", "subject-A" to 0.78f, "subject-B" to 0.82f),
        sample("controlled-impostor", null, "subject-A" to 0.84f, "subject-B" to 0.81f),
    )

    private fun sample(
        id: String,
        expected: String?,
        vararg scores: Pair<String, Float>,
    ) = SyntheticLabeledScoreSample(
        sampleId = id,
        expectedSubjectLabel = expected,
        templateScores = scores.mapIndexed { index, (subjectLabel, score) ->
            templateScore(subjectLabel, "${subjectLabel}-template-${index}", score)
        },
    )

    private fun templateSample(
        id: String,
        expected: String?,
        vararg scores: SyntheticTemplateScore,
    ) = SyntheticLabeledScoreSample(
        sampleId = id,
        expectedSubjectLabel = expected,
        templateScores = scores.toList(),
    )

    private fun templateScore(
        subjectLabel: String,
        templateLabel: String,
        score: Float,
    ) = SyntheticTemplateScore(subjectLabel, templateLabel, score)

    private fun assertFloatEquals(expected: Float, actual: Float?) {
        assertEquals(expected.toDouble(), requireNotNull(actual).toDouble(), 0.000_001)
    }
}
