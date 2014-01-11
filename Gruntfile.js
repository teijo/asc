module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      sources: {
        files: ['src/*'],
        tasks: ['default']
      },
      libScripts: {
        files: ['lib/**/*.js'],
        tasks: ['uglify']
      },
      libCss: {
        files: ['lib/**/*.css'],
        tasks: ['cssmin']
      }
    },
    shell: {
      compass: {
        command: 'compass compile'
      }
    },
    livescript: {
      src: {
        files: {
          'build/main.js': 'src/main.ls',
          'build/ui.js': 'src/ui.ls',
          'build/draw.js': 'src/draw.ls',
          'build/settings.js': 'src/settings.ls',
          'build/util.js': 'src/util.ls',
          'build/state.js': 'src/state.ls',
          'build/input.js': 'src/input.ls',
          'build/net.js': 'src/net.ls'
        }
      }
    },
    haml: {
      dist: {
        files: {
          'build/index.html': 'src/index.haml'
        }
      }
    },
    uglify: {
      options: {
        compress: false
      },
      dist: {
        files: { "build/libs.min.js": [
          "lib/require-2.1.10.js",
          "lib/jquery-1.8.2.min.js",
          "lib/*.js",
          "lib/jquery-value-bar/jquery-value-bar.js"
        ] }
      }
    },
    cssmin: {
      dist: {
        files: { "build/libs.min.css": "lib/**/*.css" }
      }
    },
    copy: {
      main: {
        files: [
          {expand: true, src: ['env.js'], dest: 'build/', filter: 'isFile'},
        ]
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-livescript');
  grunt.loadNpmTasks('grunt-shell');
  grunt.loadNpmTasks('grunt-contrib-haml');
  grunt.loadNpmTasks("grunt-contrib-uglify");
  grunt.loadNpmTasks('grunt-contrib-cssmin');
  grunt.loadNpmTasks('grunt-contrib-copy');

  grunt.registerTask('default', ['shell', 'livescript', 'haml']);
  grunt.registerTask('all', ['copy', 'uglify', 'cssmin', 'shell', 'livescript', 'haml']);
};
