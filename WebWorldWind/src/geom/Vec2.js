/*
 * Copyright (C) 2014 United States Government as represented by the Administrator of the
 * National Aeronautics and Space Administration. All Rights Reserved.
 */
/**
 * @version $Id$
 */

define([
        'src/util/Logger',
        'src/error/ArgumentError',
        'src/geom/Vec3'
    ],
    function (Logger,
              ArgumentError,
              Vec3) {
        "use strict";

        /**
         * Constructs a three component vector.
         * @alias Vec2
         * @classdesc Represents a two component vector.
         * @param x x component of vector.
         * @param y y component of vector.
         * @constructor
         */
        var Vec2 = function Vec2(x, y) {
            this[0] = x;
            this[1] = y;
        };

        /**
         * Number of elements in a Vec2.
         * @type {number}
         */
        Vec2.NUM_ELEMENTS = 2;

        /**
         * Computes the average of a specified array of points.
         * @param {Vec2[]} points The points whose average to compute.
         * @param {Vec2} result A pre-allocated Vec2 in which to return the computed average.
         * @returns {Vec2} The result argument set to the average of the specified lists of points.
         * @throws {ArgumentError} If the specified array of points is null, undefined or empty.
         */
        Vec2.average = function (points, result) {
            if (!points || points.length < 1) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "average", "missingArray"));
            }

            var count = points.length,
                vec;

            result[0] = 0;
            result[1] = 0;

            for (var i = 0, len = points.length; i < len; i++) {
                vec = points[i];

                result[0] += vec[0] / count;
                result[1] += vec[1] / count;
            }

            return result;
        };

        /**
         * Vec2 inherits all methods and representation of FLoat64Array.
         * @type {Float64Array}
         */
        Vec2.prototype = new Float64Array(Vec2.NUM_ELEMENTS);

        /**
         * Write a vector to an array at an offset.
         * @param {Array} array Array to write.
         * @param {number} offset Initial index of array to write.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         * @throws {ArgumentError} If the specified array is null, undefined, empty or too short.
         */
        Vec2.prototype.toArray = function (array, offset) {
            if (!array || array.length < offset + Vec2.NUM_ELEMENTS) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "toArray", "missingArray"));
            }

            array[offset] = this[0];
            array[offset + 1] = this[1];

            return this;
        };

        /**
         * Read a vector from an array.
         * @param {Array} array array to read.
         * @param {number} offset Initial index of array to read.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         * @throws {ArgumentError} If the specified array is null, undefined, empty or too short.
         */
        Vec2.prototype.fromArray = function (array, offset) {
            if (!array || array.length < offset + Vec2.NUM_ELEMENTS) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "fromArray", "missingArray"));
            }

            this[0] = array[offset];
            this[1] = array[offset + 1];

            return this;
        };

        /**
         * Add a vector to <code>this</code> vector, modifying <code>this</code> vector.
         * @param {Vec2} addend Vector to add.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         * @throws {ArgumentError} If the addend is null, undefined, or empty.
         */
        Vec2.prototype.add = function (addend) {
            this[0] += addend[0];
            this[1] += addend[1];

            return this;
        };

        /**
         * Subtract a vector from <code>this</code> vector, modifying <code>this</code> vector.
         * @param {Vec2} subtrahend vector to subtract
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         * @throws {ArgumentError} If the subtrahend is null, undefined, or empty.
         */
        Vec2.prototype.subtract = function (subtrahend) {
            this[0] -= subtrahend[0];
            this[1] -= subtrahend[1];
        };

        /**
         * Multiply <code>this</code> vector by a constant factor, modifying <code>this</code> vector.
         * @param {number} scaler Constant factor to multiply.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         */
        Vec2.prototype.multiply = function (scaler) {
            this[0] *= scaler;
            this[1] *= scaler;

            return this;
        };

        /**
         * Divide <code>this</code> vector by a constant factor, modifying <code>this</code> vector.
         * @param {number} divisor Constant factor to divide.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         */
        Vec2.prototype.divide = function (divisor) {
            this[0] *= divisor;
            this[1] *= divisor;

            return this;
        };

        /**
         * Mix (interpolate) a vector with <code>this</code> vector, modifying <code>this</code> vector.
         * @param {Vec2} vector Vector to mix.
         * @param {number} weight Relative weight of <code>this</code> vector
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         * @throws {ArgumentError} If the vector is null, undefined, or empty.
         */
        Vec2.prototype.mix = function (vector, weight) {
            if (!vector) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "mix", "missingVector"));
            }

            var w0 = 1 - weight,
                w1 = weight;

            this[0] = this[0] * w0 + vector[0] * w1;
            this[1] = this[1] * w0 + vector[1] * w1;

            return this;
        };

        /**
         * Negate <code>this</code> vector, modifying <code>this</code> vector.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         */
        Vec2.prototype.negate = function () {
            this[0] = -this[0];
            this[1] = -this[1];

            return this;
        };

        /**
         * Compute the scalar dot product of <code>this</code> vector and another vector.
         * @param {Vec2} vector vector to multiply
         * @returns {number} Scalar dot product of two vectors
         * @throws {ArgumentError} If the vector is null, undefined, or empty.
         */
        Vec2.prototype.dot = function (vector) {
            if (!vector) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "dot", "missingVector"));
            }

            return this[0] * vector[0] + this[1] * vector[1];
        };

        /**
         * Compute the squared length of <code>this</code> vector.
         * @returns {number} Squared magnitude of <code>this</code> vector
         */
        Vec2.prototype.lengthSquared = function () {
            return this.dot(this);
        };

        /**
         * Compute the length of <code>this</code> vector.
         * @returns {number} The magnitude of <code>this</code> vector
         */
        Vec2.prototype.length = function () {
            return Math.sqrt(this.lengthSquared());
        };

        /**
         * Construct a unit vector from <code>this</code> vector, modifying <code>this</code> vector.
         * @returns {Vec2} <code>this</code> returned in the "fluent" style.
         */
        Vec2.prototype.normalize = function () {
            var length = this.length(),
                lengthInverse = 1 / length;

            this[0] *= lengthInverse;
            this[1] *= lengthInverse;

            return this;
        };

        /**
         * Compute the squared distance from <code>this</code> vector to another vector.
         * @param {Vec2} vector Other vector
         * @returns {number} Squared distance between the vectors
         * @throws {ArgumentError} If the vector is null, undefined, or empty.
         */
        Vec2.prototype.distanceToSquared = function (vector) {
            if (!vector) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "distanceToSquared", "missingVector"));
            }

            var dx = this[0] - vector[0],
                dy = this[1] - vector[1];

            return dx * dx + dy * dy;
        };

        /**
         * Compute the distance from <code>this</code> vector to another vector.
         * @param {Vec2} vector Other vector
         * @returns {number} Squared distance between the vectors
         * @throws {ArgumentError} If the vector is null, undefined, or empty.
         */
        Vec2.prototype.distanceTo = function (vector) {
            if (!vector) {
                throw new ArgumentError(
                    Logger.logMessage(Logger.LEVEL_SEVERE, "Vec2", "distanceTo", "missingVector"));
            }

            return Math.sqrt(this.distanceToSquared(vector));
        };

        Vec2.prototype.toVec3 = function() {
            return new Vec3(this[0], this[1], 0);
        };

        return Vec2;
    });