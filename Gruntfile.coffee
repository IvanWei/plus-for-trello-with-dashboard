'use strict'

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    jade: {
      dev: {
        options: {
          pretty: true
        },
        files: {
          'build/index.html': 'src/index.jade'
        }
      }
    }

    coffee: {
      dev: {
        files: [
          {
            expand: true
            cwd: 'src/'
            src: ['dist/*.coffee']
            dest: 'build/'
            filter: 'isFile'
            ext: '.js'
          }
        ]
      }
      build: {
        options: {
          bare: false
          join: true
        },
        files: {
          'temp/dist/dashboard.min.js': 'src/dist/*.coffee'
        }
      }
    }

    cssmin: {
      build: {
        options:
          shorthandCompacting: false
          roundingPrecision: -1
        files: 'temp/css/dashboard.min.css': 'src/css/*'
      }
    }

    uglify:
      build: {
        options: {
          beautify: false
          mangle: false
        }
        files: {
          #'temp/dist/dashboard.min.js': 'temp/dist/dashboard.js'
         # 'temp/libs/lodash.v3.min.js': 'temp/libs/lodash.v3.js'
        }
      }

    clean:
      dev: 'build/*'
      build: ['temp/*', 'build/*', '!build/*.html']

    copy:
      dev: {
        files: {
          'build/libs/jquery.v2.1.min.js': 'node_modules/jquery/dist/jquery.min.js'
          'build/libs/lodash.v3.js': 'node_modules/lodash/index.js'
          'build/libs/taffydb.v2.7.min.js': 'node_modules/taffydb/taffy-min.js'
          'build/css/pure-min.css': 'node_modules/purecss/build/pure-min.css'
          'build/css/dashboard.css': 'src/css/dashboard.css'
          'build/css/purecssLayout.css': 'src/css/purecssLayout.css'
          'build/libs/chartist.v0.9.min.js': 'node_modules/chartist/dist/chartist.min.js'
          'build/css/chartist.v0.9.min.css': 'node_modules/chartist/dist/chartist.min.css'
          'build/CNAME': 'CNAME'
          'build/README.md': 'README.md'
        }
      }
      build:
        files: [
          {
            expand: true
            cwd: 'temp/'
            src: ['css/*', '**/*.min.js']
            dest: 'build/'
            filter: 'isFile'
          }
        ]

    watch:
      livereload:
        options:
          livereload: true
        files: [
          'src/**/*.{coffee,jade,css}'
        ]
        tasks: [
          'default'
        ]

    connect: {
      example: {
        options: {
          port: 4000,
          base: ['build'],
          livereload: true,
          open: 'http://localhost:4000/index.html'
        }
      }
    }


  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)
  # Register tasks
  grunt.registerTask 'develop', [
    'default'
    'connect'
    'watch'
  ]
  #grunt.registerTask 'server', [
  #  'build'
  #  'connect'
  #]
  #grunt.registerTask 'build', [
  #  'clean:build'
  #  'copy:build'
  #  'cssmin'
  #  'uglify'
  #]
  grunt.registerTask 'default', [
    'clean:dev'
    'copy:dev'
    'jade'
    'coffee:dev'
  ]
  return
